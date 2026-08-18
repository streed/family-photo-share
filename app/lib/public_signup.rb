# Whether a stranger can create an account on their own.
#
# This is a private family archive, so open sign-up is off unless the operator
# deliberately turns it on with ALLOW_PUBLIC_SIGNUP. Being invited is a separate
# path and always works: someone holding a valid family invitation can finish
# signing up whatever this flag says, otherwise turning it off would take the
# invitation system down with it.
module PublicSignup
  ENV_VAR = "ALLOW_PUBLIC_SIGNUP".freeze

  # Read per call rather than frozen at boot: the value is a single hash lookup,
  # and this way a deployment that changes the variable takes effect on restart
  # without a second source of truth in config to keep in step.
  #
  # "1", "true", "yes" and "on" enable it. Anything else — including an unset or
  # empty variable — leaves it off.
  def self.enabled?
    ActiveModel::Type::Boolean.new.cast(ENV[ENV_VAR]) || false
  end
end
