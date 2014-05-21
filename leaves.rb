require 'rake'

module Rake
	module Leaves
		# Set the required task arguments
		def required_args (*args)
			Rake.application.last_required_args = args
		end

		# Set the optional task arguments
		def optional_args (args)
			Rake.application.last_optional_args = args
		end

		# Alias a task argument
		def alias_arg (new_name, original_name)
			original_name = original_name.to_sym
			aliases = Rake.application.last_arg_aliases
			aliases[original_name] ||= []
			aliases[original_name].push new_name
			Rake.application.last_arg_aliases = aliases
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
			@args ||= required_args
				.merge(optional_args)
				.inject({}) do |args, (name, default)|
					arg_aliases[name].reverse.each { |alias_name|
						args[name] ||= ENV[alias_name.to_s]
					} if arg_aliases[name]
					args[name] ||= ENV[name.to_s] || default
					args[name] = request_argument name if
						args[name].nil? && required_args.keys.include?(name)
					args
				end
		end

		# Add a required argument to the task
		def add_required_arg (name)
			required_args[name.to_sym] = nil
		end

		# Add an optional argument to the task (along with an optional default)
		def add_optional_arg (name, default = nil)
			optional_args[name.to_sym] = default
		end

		# Alias a task argument (same usage as alias_method)
		def add_arg_alias (new_name, original_name)
			arg_aliases[original_name.to_sym] ||= []
			arg_aliases[original_name.to_sym].push new_name.to_sym
		end

		private

		# required_args getter, cleaner than aliasing initialize to set
		# the default value
		def required_args
			@required_args ||= {}
		end

		# optional_args getter, cleaner than aliasing initialize to set
		# the default value
		def optional_args
			@optional_args ||= {}
		end

		# arg_aliases getter, cleaner than aliasing initialize to set
		# the default value
		def arg_aliases
			@arg_aliases ||= {}
		end

		# Request an argument from the user via standard in
		def request_argument  (name)
			STDOUT.print "#{@name} requires #{name}: "
			ENV[name.to_s] = STDIN.gets.strip
		end
	end

	module TaskManager
		attr_writer :last_required_args, :last_optional_args, :last_arg_aliases
		
		alias_method :original_intern, :intern

		# Add arguments to the task immediately after creating it
		def intern (*args)
			task = original_intern *args
			add_args task
			task
		end

		# last_required_args getter, cleaner than aliasing initialize to set
		# the default value
		def last_required_args
			@last_required_args ||= {}
		end

		# last_optional_args getter, cleaner than aliasing initialize to set
		# the default value
		def last_optional_args
			@last_optional_args ||= {}
		end

		# last_arg_aliases getter, cleaner than aliasing initialize to set
		# the default value
		def last_arg_aliases
			@last_arg_aliases ||= {}
		end
		
		private

		# Add arguments to a task based on the last values set (and then clear
		# the last values so they don't affect the next task)
		def add_args (task)
			last_required_args.each { |arg|
				task.add_required_arg arg
			}
			last_optional_args.each { |arg, default|
				task.add_optional_arg arg, default
			}
			last_arg_aliases.each { |original_name, new_names|
				new_names.each { |new_name|
					task.add_arg_alias new_name, original_name
				}
			}
			@last_required_args = nil
			@last_optional_args = nil
			@last_arg_aliases = nil
		end
	end

	module DSL

		# Include the new methods that should accessible globally
		include Leaves
		private(*Leaves.instance_methods(false))
	end
end