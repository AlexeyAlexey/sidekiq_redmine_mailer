class Sidekiq::RedmineMailer::Proxy
  delegate :to_s, :to => :actual_message

  def initialize(mailer_class, method_name, *args)
    @mailer_class = mailer_class
    @method_name = method_name
    unless Sidekiq.server?
      if defined?(RedmineApp)
        class_constant = "Sidekiq::RedmineMailer::BeforeFilter::#{mailer_class}".constantize
        mailer_obj = class_constant.new
        *@args = mailer_obj.send(method_name, args)
      else
        *@args = *args
      end
    else
      *@args = *args
    end
  end

  def actual_message
    @actual_message ||= @mailer_class.send(:new, @method_name, *@args).message
  end

  def deliver
    return deliver! if Sidekiq::RedmineMailer.excludes_current_environment?
    Sidekiq::RedmineMailer::Worker.client_push(to_sidekiq)
  end

  def excluded_environment?
    Sidekiq::RedmineMailer.excludes_current_environment?
  end

  def deliver!
    actual_message.deliver
  end

  def method_missing(method_name, *args)
    actual_message.send(method_name, *args)
  end

  def to_sidekiq
    params = {
      'class' => Sidekiq::RedmineMailer::Worker,
      'args' => [@mailer_class.to_s, @method_name, @args]
    }
    params.merge(@mailer_class.get_sidekiq_options)
  end
end
