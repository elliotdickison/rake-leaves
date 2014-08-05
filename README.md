# rake-leaves
User-friendly parameter definitions and named arguments for rake tasks.

## Defining Parameters

To define required parameters for a task, pass each parameter name as a symbol to the "params" method immediately before the task definition (similar to the way the "desc" method can be used to set the task description).

```ruby
desc "Just a test task, nothing to see here..."
params :first_name, :last_name
task :testing_leaves do |task|

end
```

Optional parameters can be passed as a hash to the "optional_params" method. The hash keys are the parameter names and the hash values are the default arguments.

```ruby
params :first_name, :last_name
optional_params hair_color: 'purple', date_of_birth: nil
task :testing_leaves do |task|

end
```

## Sending Arguments

Arguments are sent as "name=value" pairs following the rake call.

```bash
rake testing_leaves first_name=Bob last_name=Saggit
```

## Accessing Arguments

Arguments are available via the Task.args instance method.

```ruby
params :first_name, :last_name
task :testing_leaves do |task|
	puts task.args # {first_name: 'value', last_name: 'something'}
end
```

## Global Gotcha

Because arguments are passed to the entire rake process instead of to each task individually, tasks that share parameter names will always receive the same argument values for those parameters if run in the same process.