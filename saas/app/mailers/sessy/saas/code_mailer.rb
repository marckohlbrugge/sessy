class Sessy::Saas::CodeMailer < Sessy::Saas::ApplicationMailer
  def sign_in_code(magic_link)
    @code = magic_link.code
    mail to: magic_link.user.email_address, subject: "Your Sessy code is #{@code}"
  end
end
