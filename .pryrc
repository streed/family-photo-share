# .pryrc - Pry configuration
Pry.config.prompt = PryRails::RAILS_PROMPT if defined?(PryRails::RAILS_PROMPT)

# Useful aliases (only if debugger commands exist)
if Pry.config.commands['continue']
  Pry.config.commands.alias_command 'c', 'continue'
  Pry.config.commands.alias_command 's', 'step'
  Pry.config.commands.alias_command 'n', 'next'
  Pry.config.commands.alias_command 'f', 'finish'
end

# Better output formatting
begin
  require 'awesome_print'
  Pry.config.print = proc do |output, value|
    Pry::Helpers::BaseHelpers.stagger_output("=> #{value.ai}", output)
  end
rescue LoadError
  # awesome_print not available, use default formatting
end