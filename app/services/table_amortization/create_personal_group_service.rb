module TableAmortization
  class CreatePersonalGroupService
    include ActionView::Helpers::NumberHelper
    
    def initialize(loan)
			@loan = loan
    end

    def execute
      create_payments
    end

    private

    def create_payments
      payments = []
      movements = []

      (1..@loan.payments_number).each do |payment_number|
        payments << {
          period: payment_number,
          personal_group_loan_id: @loan.id,
          payment_date: (@loan.start_date + (payment_number - 1).month),
          capital_amount: @loan.capital_amount,
          interest_amount: @loan.interest_monthly,
          period_amount: @loan.payment_amount,
          status: 'light'
        }

        movements << {
          movement_type_id: 2,
          amount: 0.0,
          personal_group_loan_id: @loan.id,
          period: payment_number
        }
      end

      PaymentPersonalGroup.create!(payments)
      LoanMovementPersonalGroup.create!(movements)
      @loan.update!(
        sum_interest: (@loan.interest_monthly * @loan.payments_number).round(2),
        sum_capital: @loan.amount,
        sum_payment_amount: (@loan.amount + (@loan.interest_monthly * @loan.payments_number).round(2)).round(2)
      )
    end
	end    
end
