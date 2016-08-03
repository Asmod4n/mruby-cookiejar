class Cookiejar
  class Error < StandardError; end
  class UserExistsError < Error; end
  class PasswordError < Error; end
  class UserNotExistsError < Error; end
end
