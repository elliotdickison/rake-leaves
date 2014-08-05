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

		# Allow the task to request missing arguments from the user
		def request_missing_params
			Rake.application.last_request_missing_params = true
		end
	end

	class Task

		attr_writer :request_missing_params
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
			unless @args
				errors = []
				@args = required_params
					.merge(optional_params)
					.inject({}) do |args, (name, default)|

						# Check for a value supplied under an alias
						param_aliases[name].reverse.each { |alias_name|
							args[name] ||= ENV[alias_name.to_s]
						} if param_aliases[name]

						# Set the arg to user input or its default value
						args[name] ||= ENV[name.to_s] || default

						# If an argument is a) missing and b) required, then
						# request it or generate an error message
						if args[name].nil? && required_params.keys.include?(name)
							if @request_missing_params
								args[name] = request_argument name 
							else
								errors.push "Missing argument '#{name}'"
							end
						end

						args
					end
				abort errors.join "\n" unless errors.empty?
			end
			@args
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
			STDOUT.print "Enter #{name} for #{@name}: "
			ENV[name.to_s] = STDIN.gets.strip
		end
	end

	module TaskManager
		attr_writer :last_required_params, :last_optional_params, :last_param_aliases,
			:last_request_missing_params
		
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
			task.request_missing_params = @last_request_missing_params
			@last_required_params = nil
			@last_optional_params = nil
			@last_param_aliases = nil
			@last_request_missing_params = nil
		end
	end

	module DSL

		# Include the new methods that should be accessible globally
		include Leaves
		private(*Leaves.instance_methods(false))
	end
end