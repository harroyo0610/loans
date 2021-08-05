class PersonalGroupLoansController < ApplicationController
  def new
    @loan = PersonalGroupLoan.new
  end

  def create
    loan = CreatePersonalGroupStrategy.new(params[:personal_group_loan]).execute
    loan.update_status
    if loan
      create_log("Se ha creado el prestamo personal grupal #{loan.client.fullname}.")
      flash[:success] = success_text

      redirect_to edit_personal_group_loan_path loan
    else
      flash[:danger] = loan.errors.full_messages.map{ |e| errors_map[e] || errors_map.values }.join(', ')

      render 'new'
    end
  end

  def edit
    @loan = PersonalGroupLoan.find(params[:id])
    @payments = @loan.payment_personal_groups.order('period asc')
    @movements = @loan.loan_movement_personal_groups.where('amount > 0')
    @last_weekly_payment = last_weekly_payment
  end

  def update
    loan = PersonalGroupLoan.find(params[:id])
    loan = Strategy::UpdatePersonalGroup.new(loan: loan, params: params[:personal_group_loan]).execute
    loan.update_status
    @last_weekly_payment = loan.last_weekly_payment
    if loan
      create_log("Se ha actualizado el prestamo personal grupal #{loan.client.fullname}.")
      flash[:success] = success_text

      redirect_to edit_personal_group_loan_path loan
    else
      flash[:danger] = loan.errors.full_messages.map{ |e| errors_map[e] || errors_map.values }.join(', ')

      render 'new'
    end
  end

  def index
    @filter = ''
    @filter = params[:filter] if params.key?(:filter)

    filter = @filter.to_sym
    @loans = PersonalGroupLoan.index(filter)
  end

  def destroy
    loan = PersonalGroupLoan.find(params[:id])
    if loan.delete
      delete(loan)

      flash[:success] = success_text
    else
      flash[:danger] = error_text
    end

    redirect_to personal_group_loans_path(@loan)
  end

  def pay_full
    @loan = PersonalGroupLoan.find(params[:id])

    if @loan.update(state_id: 4)
      loan = Strategy::UpdatePersonalGroup.new(loan: @loan, params: { finished_amount: params[:finished_amount] } ).execute
      loan.update_status
      @payments = @loan.payment_personal_groups.order('period asc')
      @movements = @loan.loan_movement_personal_groups.where('amount > 0')
      @last_weekly_payment = last_weekly_payment

      flash[:success] = success_text
    end

    redirect_to edit_personal_group_loan_path loan
  end

  def saldar_pay
    @loan = PersonalGroupLoan.find(params[:id])

    @loan.update(state_id: 3)

    redirect_to loan_reports_finished_amount_path
  end

  def last_weekly_payment
    @loan.last_weekly_payment
  end

  def delete(loan)
    loan&.loan_movement_personal_groups&.delete
    loan&.payment_personal_groups&.delete
  end
end
