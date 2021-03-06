class LoanMovementsController < ApplicationController
  before_action :is_view_permitted?, only:[:create, :edit, :update, :destroy]

  def edit
    payment = WeeklyPayment.find(params[:id])
    @loan_movement = LoanMovement.where(loan_id: payment.loan_id).where(movement_type_id: 2).where(week: payment.week).last
    respond_to do |format|
      format.js
    end
  end

  def update
    loan_movement = LoanMovement.find(params[:id])
    loan_movement.fill_other_movements(params[:amount])
    @loan = loan_movement.loan

    create_log("Ha sido actualizado el movimiento de la semana: #{loan_movement.week}, monto: #{loan_movement.amount} del grupo #{@loan.name}, ciclo #{@loan.cycle}.")

    if params[:movement_type_id] == '2'
      TransactionsController.new.create(amount: params[:amount], loan_id: params[:loan_id], loan_movement: loan_movement)
      adjust_payment
      BasePaymentsController.new(@loan)
    end
    @weekly_payments = @loan.weekly_payments.order('week ASC')
    @client_movements = @loan.loan_movements.where('amount > 0')
    @last_weekly_payment = @loan.last_weekly_payment
  end

  def destroy
    @loan_movement = LoanMovement.find(params[:id])
    @loan = @loan_movement.loan

    create_log("Ha sido removido el movimiento de la semana: #{@loan_movement.week}, monto: #{@loan_movement.amount} del grupo #{@loan.name}, ciclo #{@loan.cycle}.")

    if @loan_movement.update(amount: 0.0)
      adjust_payment
      @weekly_payments = @loan.weekly_payments.order('week ASC')
      @client_movements = @loan.loan_movements.where("amount > 0")
      @last_weekly_payment = @loan.last_weekly_payment
      respond_to do |format|
        format.js
      end
    else
      redirect_to edit_client_path(client)
    end
  end

  def adjust_payment
    loan_movement = LoanMovement.find(params[:id])

    if params.key?(:comments)
      loan_movement.update!(comments: params[:comments])
    end
  end

  def create
    if movement_params[:movement_type_id] == '2'
      @loan = loan
      create_log("Ha sido creado el movimiento con el monto: #{movement_params[:amount]}, semana: #{payment_week} del grupo #{@loan.name}, ciclo #{@loan.cycle}.")
      if movement_params[:week].to_i > 16
        create_movement
        AdjustLoansController.new(loan, movement_params)
        set_variables
      else
        movement = movements.find_by(week: payment_week)

        if movement.update(
          amount: movement_params[:amount], 
          loan_id: movement_params[:loan_id], 
          movement_type_id: movement_params[:movement_type_id], 
          comments: movement_params[:comments]
        )
          AdjustLoansController.new(loan, movement_params)
          set_variables

          respond_to do |format|
            format.js
          end
        else
          redirect_to edit_client_path(@client)
        end
      end 
    else
      create_movement
      set_variables

      respond_to do |format|
        format.js
      end
    end
  end

  def movements
    LoanMovement.where(loan_id: movement_params[:loan_id]).where(movement_type_id: movement_params[:movement_type_id])
  end
  
  def payments
    WeeklyPayment.where(loan_id: movement_params[:loan_id])
  end

  def payment_week
    payments.where('payment_date <= ?', DateTime.now).order('id DESC').first&.week
  end

  def loan
    Loan.find(movement_params[:loan_id])
  end

  def create_movement
    LoanMovement.create(movement_params)
    CreateWeeklyPaymentsController.new(loan).create_weekly_payment(movement_params[:week])
  end

  def set_variables
    @client_movements = @loan.loan_movements.where('amount > 0')
    @weekly_payments = @loan.weekly_payments.order('week ASC')
    @last_weekly_payment = @loan.last_weekly_payment
  end

  private

  def movement_params
    params.require(:loan_movement).permit(
      :amount, 
      :loan_id, 
      :movement_type_id, 
      :comments,
      :week
    )
  end
end
