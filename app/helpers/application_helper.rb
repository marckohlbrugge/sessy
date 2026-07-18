module ApplicationHelper
  def show_auth_warning?
    return false if Sessy.saas?

    !Rails.env.local? &&
      ENV["HTTP_AUTH_USERNAME"].blank? &&
      ENV["HTTP_AUTH_PASSWORD"].blank? &&
      ENV["DISABLE_AUTH_WARNING"].blank?
  end
end
