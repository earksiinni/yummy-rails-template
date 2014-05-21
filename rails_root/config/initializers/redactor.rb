# config/initializers/redactor.rb
# Overrides the user class

module RedactorRails
  def self.devise_user
    %s(<%= @opts[:user_model].underscore %>) # name of your user class
  end

  # You may override this to support legacy schema.
  # def self.devise_user_key
  #   "#{self.devise_user.to_s}_id".to_sym
  # end
end
