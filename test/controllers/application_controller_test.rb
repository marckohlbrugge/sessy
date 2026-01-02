require "test_helper"

class ApplicationControllerTest < ActionDispatch::IntegrationTest
  test "should switch locale to pt-BR" do
    get root_path(locale: "pt-BR")
    assert_response :success
    assert_select "h1", "Origens"
    assert_equal :"pt-BR", I18n.locale
  end

  test "should default to en locale" do
    get root_path
    assert_equal :en, I18n.locale
    assert_select "h1", "Sources"
  end
end
