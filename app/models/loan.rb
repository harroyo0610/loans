class Loan < ApplicationRecord
  has_many :loan_clients
  has_many :loan_movements
  has_many :clients, through: :loan_clients
  belongs_to :state
  has_many :weekly_payments
  has_many :contract_loans
  has_many :contracts, through: :contract_loans

  scope :order_desc, -> { order('created_at DESC') }
  scope :pending, -> { where(state_id: 1).order_desc }
  scope :active, -> { where(state_id: 2).order_desc }
  scope :finished, -> { where(state_id: 3).order_desc }

  enum status: {
    pending_accept: 'pending_accept',
    pending_pay: 'pending_pay',
    paid: 'paid',
    not_paid: 'not_paid'
  }

  enum type: {
    team: 'team',
    personal: 'personal',
    personal_group: 'personal_group'
  }

  validates :name, uniqueness: { scope: :cycle, message: 'Ya existe un grupo con este nombre', case_sensitive: false }

  def self.index(filter=nil)
    case filter
    when :active
      Loan.pending + Loan.active
    when :finished
      Loan.finished
    else
      Loan.all
    end
  end

  def self.list(loans_filtered)
    loans = []
    loans_filtered.each do |loan|
      loans << {
        loan: loan,
        status: loan.status
      }
    end

    loans
  end

  def pending_payment
    payments_before_today.where(status: 'danger').count > 0 && DateTime.now.between?(self.start_date, self.end_date)
  end

  def last_payment_bool
    payments_before_today.last&.payment_date.to_i > 1.week.ago.to_i
  end

  def payments_before_today
    self.weekly_payments.where('payment_date < ?', DateTime.now)
  end

  def movements_before_today
    self.loan_movements.where('week <= ?', self.payments_last_week)
  end

  def payments_sum
    payments_order_asc.sum(:week_payment)
  end

  def movements_sum
    movements_order_asc.sum(:amount)
  end

  def payments_order_asc
    payments_before_today.order('week ASC')
  end

  def movements_order_asc
    movements_before_today.order('week ASC')
  end

  def payments_last_week
    payments_order_asc.last&.week
  end
  
  def update_status
    status = if self.state.name == 'pending'
      :pending_accept
    elsif self.pending_payment == true
      :pending_pay
    elsif self.movements_sum >= self.payments_sum 
      :paid 
    elsif self.not_paid_past_due_date == true
      :not_paid
    else
      :paid
    end
    
    self.update(status: status)

    status
  end

  def update_loan_sums
    movs = self.movements_order_asc.where('amount > 0')
    sum_payment_capital = 0
    sum_payment_interest = 0
    sum_week_payment = 0
    
    movs.each do |m|
      sum_payment_capital += m.weekly_payment.payment_capital
      sum_payment_interest += m.weekly_payment.payment_interest
      sum_week_payment += m.weekly_payment.week_payment
    end
    
    self.update(
      sum_payment_capital: sum_payment_capital,
      sum_payment_interest: sum_payment_interest,
      sum_week_payment: sum_week_payment
    )
  end

  def last_weekly_payment
    payments = self.weekly_payments

    return 0 if payments.where(status: 'success').count >= 15  

    last_payment = nil
    payments.order('week ASC').each_with_index do |weekly_payment, index|
      last_payment = weekly_payment if weekly_payment&.loan_movement&.amount.to_f > 0 || index == 0
    end
    
    last_payment&.wallet_amout - (self.loan_amount.to_f/10)
  end

  def not_paid_past_due_date
    DateTime.now > self.end_date && self.movements_sum < self.payments_sum 
  end
end
