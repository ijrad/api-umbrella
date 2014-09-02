require "api_umbrella/attributify_data"

class ApiUser
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Userstamp
  include Mongoid::Paranoia
  include Mongoid::Delorean::Trackable
  include Mongoid::EmbeddedErrors
  include ApiUmbrella::AttributifyData

  # Fields
  field :_id, :type => String, :default => lambda { UUIDTools::UUID.random_create.to_s }
  field :api_key
  field :first_name
  field :last_name
  field :email
  field :website
  field :use_description
  field :registration_source
  field :throttle_by_ip, :type => Boolean
  field :disabled_at, :type => Time
  field :roles, :type => Array

  # Virtual fields
  attr_accessor :terms_and_conditions, :no_domain_signup

  # Relations
  embeds_one :settings, :class_name => "Api::Settings"

  # Indexes
  index({ :api_key => 1 }, { :unique => true })

  # Validations
  #
  # Provide full sentence validation errors. This doesn't really vibe with how
  # Rails intends to do things by default, but the we're super picky about
  # wording of things on the AFDC site which uses these messages. MongoMapper
  # and ActiveResource combined don't give great flexibility for error message
  # handling, so we're stuck with full sentences and changing how the errors
  # are displayed.
  validates :api_key,
    :uniqueness => true
  validates :first_name,
    :presence => { :message => "Provide your first name." }
  validates :last_name,
    :presence => { :message => "Provide your last name." }
  validates :email,
    :presence => { :message => "Provide your email address." },
    :format => {
      :with => /.+@.+\..+/,
      :allow_blank => true,
      :message => "Provide a valid email address.",
    }
  validates :website,
    :presence => { :message => "Provide your website URL." },
    :format => {
      :with => /\w+\.\w+/,
      :message => "Your website must be a valid URL in the form of http://data.gov",
    },
    :unless => lambda { |user| user.no_domain_signup }
  validates :terms_and_conditions,
    :acceptance => {
      :message => "Check the box to agree to the terms and conditions.",
      :accept => true,
    },
    :on => :create,
    :allow_nil => false

  # Callbacks
  before_validation :normalize_terms_and_conditions
  after_save :handle_rate_limit_mode

  # Ensure the api key is generated (even if validations are disabled)
  before_validation :generate_api_key, :on => :create
  before_create :generate_api_key

  # Nested attributes
  accepts_nested_attributes_for :settings

  # Mass assignment security
  attr_accessible :first_name,
    :last_name,
    :email,
    :website,
    :use_description,
    :terms_and_conditions,
    :registration_source,
    :as => [:default, :admin]
  attr_accessible :roles,
    :throttle_by_ip,
    :enabled,
    :settings_attributes,
    :as => :admin

  def self.human_attribute_name(attribute, options = {})
    case(attribute.to_sym)
    when :email
      "Email"
    when :terms_and_conditions
      "Terms and conditions"
    when :website
      "Web site"
    else
      super
    end
  end

  def self.existing_roles
    existing_roles = ApiUser.distinct(:roles)

    Api.all.each do |api|
      if(api.settings && api.settings.required_roles)
        existing_roles += api.settings.required_roles
      end

      if(api.sub_settings)
        api.sub_settings.each do |sub|
          if(sub.settings && sub.settings.required_roles)
            existing_roles += sub.settings.required_roles
          end
        end
      end
    end

    existing_roles.uniq!

    existing_roles
  end

  def as_json(*args)
    hash = super(*args)

    if(!self.valid?)
      hash.merge!(:errors => self.errors.full_messages)
    end

    hash
  end

  def enabled
    self.disabled_at.nil?
  end

  def enabled=(enabled)
    if(enabled.to_s == "false")
      if(self.disabled_at.nil?)
        self.disabled_at = Time.now
      end
    else
      self.disabled_at = nil
    end
  end

  def api_key_preview
    self.api_key.truncate(9)
  end

  def api_key_hides_at
    @api_key_hides_at ||= self.created_at + 10.minutes
  end

  private

  def normalize_terms_and_conditions
    # Handle the acceptance validation regardless of if it comes from the JSON
    # api (true values) or from an HTML form ('1' values).
    self.terms_and_conditions = (self.terms_and_conditions == true || self.terms_and_conditions == '1')
    true
  end

  def generate_api_key
    unless self.api_key
      # Generate a key containing A-Z, a-z, and 0-9 that's 40 chars in
      # length.
      key = ""
      while key.length < 40
        key = SecureRandom.base64(50).delete("+/=")[0, 40]
      end

      self.api_key = key
    end
  end

  # After the API is saved, clear out any left-over rate_limits for settings
  # where the rate limit mode is no longer "custom."
  #
  # Ideally this would be an after_save callback inside the Settings model, but
  # turning on cascade_callbacks seems to lead to tack level too deep errors.
  def handle_rate_limit_mode
    if(self.settings.present?)
      if(self.settings.rate_limit_mode != "custom")
        self.settings.rate_limits.clear
      end
    end

    true
  end
end
