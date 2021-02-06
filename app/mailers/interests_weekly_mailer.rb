class InterestsWeeklyMailer < ApplicationMailer
  default from: 'ferb@losinfiltrados.com'

  def send_report(report)
    attachments["reporte de intereses #{1.week.ago.strftime('%F')}-#{DateTime.now.strftime('%F')}.csv"] = {mime_type: 'text/csv', content: report}
    mail(to: 'delvecontabilidad01@gmail.com, huarci@gmail.com', subject: "reporte de intereses #{1.week.ago.strftime('%F')}-#{DateTime.now.strftime('%F')}")
  end
end