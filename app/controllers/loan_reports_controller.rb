class LoanReportsController < ApplicationController
  include ActionView::Helpers::NumberHelper
  MONTHS = {
    '01' => 'Enero',
    '02' => 'Febrero',
    '03' => 'Marzo',
    '04' => 'Abril',
    '05' => 'Mayo',
    '06' => 'Junio',
    '07' => 'Julio',
    '08' => 'Agosto',
    '09' => 'Septiembre',
    '10' => 'Octubre',
    '11' => 'Noviembre',
    '12' => 'Diciembre'
  }

  def recents
    @last_six_months = last_six_months
    @loans = loans_recents
    @sums = {
      amount: number_to_currency(@loans.sum(:loan_amount), precision:2),
      weekly_amount: number_to_currency(@loans.sum(:weekly_amount), precision:2)
    }
  end

  def extensions
    @last_six_months = last_six_months
    @loans = loans_extensions
    @sums = {
      amount: number_to_currency(@loans.sum(:loan_amount), precision:2),
      weekly_amount: number_to_currency(@loans.sum(:weekly_amount), precision:2)
    }
  end

  def client_loans
    clients = Client.includes(:loans).order('id ASC')
    @clients = []
    clients.each do |c|
      @clients << {
        id: c.id,
        full_name: "#{c.name} #{c.last_name} #{c.mother_last_name}",
        birth_date: c.birth_date,
        groups: c.loans.map(&:name).uniq.join(', ')
      }
    end
  end

  def interests_montly
    @last_six_months = last_six_months
    loans_interests
  end

  def finished_amount
    @loans = PersonalGroupLoan.where(state_id: 4).order('created_at desc')
  end

  private

  def last_six_months
    (0..6).to_a.map{ |n| ["#{MONTHS[n.month.ago.strftime('%m')]}-#{n.month.ago.strftime('%Y')}", n.month.ago.strftime('%Y-%m-01')]}
  end

  def loans_recents
    month = Date.today.at_beginning_of_month
    month = params[:month].to_date if params.key?(:month) 
    @month_name = "#{MONTHS[month.to_date.strftime('%m')]}-#{month.to_date.strftime('%Y')}"

    Loan.where(cycle: 1).where(disbursement_date: month..month.end_of_month.end_of_day).order('disbursement_date DESC')
  end

  def loans_extensions
    month = Date.today.at_beginning_of_month
    month = params[:month].to_date if params.key?(:month) 
    @month_name = "#{MONTHS[month.to_date.strftime('%m')]}-#{month.to_date.strftime('%Y')}"

    Loan.where('cycle > 1').where(disbursement_date: month..month.end_of_month.end_of_day).order('disbursement_date DESC')
  end

  def loans_interests
    month = Date.today.at_beginning_of_month
    month = params[:month].to_date if params.key?(:month) 
    @month_name = "#{MONTHS[month.to_date.strftime('%m')]}-#{month.to_date.strftime('%Y')}"
    loans = WeeklyPayment
              .joins(:loan)
              .where(payment_date: month..month.end_of_month.end_of_day)
              .group(['loans.name', 'loans.cycle', 'loans.id'])
              .order('loans.created_at asc')
              .sum('payment_interest')

    @loans = []
    loans.each_with_index do |loan, i|
      @loans <<  { index: i+1, id: loan[0][2], cycle: loan[0][1], group: loan[0][0], interest: loan[1].round(2) }
    end

    finished_loans = Loan.joins(:weekly_payments).where(state_id: 3).where('weekly_payments.payment_date': month..month.end_of_month.end_of_day).order('loans.created_at asc')
    finished_loans.each do |loan|
      @loans << { id: loan.id, cycle: loan.cycle, group: loan.name, interest: loan.weekly_payments.where('payment_date >= ?', month).sum(:payment_interest) }
    end

    @loans.uniq! {|e| e[:id] }

    @sum_interests = @loans.map {|s| s[:interest]}.reduce(0, :+)
  end
end
