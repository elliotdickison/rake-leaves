require 'rake'

module Rake
	module Leaves
		# Define required task parameters
		def params (*params)
			Rake.application.last_required_params = params
		end

		# Define optional task parameters
		def optional_params (params)
			Rake.application.last_optional_params = params
		end

		# Alias a task parameter
		def alias_param (new_name, original_name)
			original_name = original_name.to_sym
			aliases = Rake.application.last_param_aliases
			aliases[original_name] ||= []
			aliases[original_name].push new_name
			Rake.application.last_param_aliases = aliases
		end
	end

	class Task

		alias_method :original_invoke_with_call_chain, :invoke_with_call_chain

		# Call self.args in self.invoke_with_call_chain so that all the arg
		# checking is done before any tasks are executed
		def invoke_with_call_chain (*args)
			self.args
			original_invoke_with_call_chain *args
		end

		# Gathers and returns all args for the task. Missing required args are
		# requested via standard in
		def args
			@args ||= required_params
				.merge(optional_params)
				.inject({}) do |args, (name, default)|
					param_aliases[name].reverse.each { |alias_name|
						args[name] ||= ENV[alias_name.to_s]
					} if param_aliases[name]
					args[name] ||= ENV[name.to_s] || default
					args[name] = request_argument name if
						args[name].nil? && required_params.keys.include?(name)
					args
				end
		end

		# Add a required argument to the task
		def add_required_param (name)
			required_params[name.to_sym] = nil
		end

		# Add an optional argument to the task (along with an optional default)
		def add_optional_param (name, default = nil)
			optional_params[name.to_sym] = default
		end

		# Alias a task argument (same usage as alias_method)
		def add_param_alias (new_name, original_name)
			param_aliases[original_name.to_sym] ||= []
			param_aliases[original_name.to_sym].push new_name.to_sym
		end

		private

		# required_params getter, cleaner than aliasing initialize to set
		# the default value
		def required_params
			@required_params ||= {}
		end

		# optional_params getter, cleaner than aliasing initialize to set
		# the default value
		def optional_params
			@optional_params ||= {}
		end

		# param_aliases getter, cleaner than aliasing initialize to set
		# the default value
		def param_aliases
			@param_aliases ||= {}
		end

		# Request an argument from the user via standard in
		def request_argument  (name)
			STDOUT.print "#{@name} requires #{name}: "
			ENV[name.to_s] = STDIN.gets.strip
		end
	end

	module TaskManager
		attr_writer :last_required_params, :last_optional_params, :last_param_aliases
		
		alias_method :original_intern, :intern

		# Add arguments to the task immediately after creating it
		def intern (*args)
			task = original_intern *args
			add_params task
			task
		end

		# last_required_params getter, cleaner than aliasing initialize to set
		# the default value
		def last_required_params
			@last_required_params ||= {}
		end

		# last_optional_params getter, cleaner than aliasing initialize to set
		# the default value
		def last_optional_params
			@last_optional_params ||= {}
		end

		# last_param_aliases getter, cleaner than aliasing initialize to set
		# the default value
		def last_param_aliases
			@last_param_aliases ||= {}
		end
		
		private

		# Add parameters to a task based on the last parameters defined (and then clear
		# the last parameters so they don't affect the next task)
		def add_params (task)
			last_required_params.each { |arg|
				task.add_required_param arg
			}
			last_optional_params.each { |arg, default|
				task.add_optional_param arg, default
			}
			last_param_aliases.each { |original_name, new_names|
				new_names.each { |new_name|
					task.add_param_alias new_name, original_name
				}
			}
			@last_required_params = nil
			@last_optional_params = nil
			@last_param_aliases = nil
		end
	end

	module DSL

		# Include the new methods that should accessible globally
		include Leaves
		private(*Leaves.instance_methods(false))
	end
end