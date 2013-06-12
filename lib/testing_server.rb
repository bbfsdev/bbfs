require 'testing_server/testing_server'

module TestingServer
  Params.integer('testing_server_port', 4445, 'Remote port to synchronization between testing servers')
  #Params.integer('email_delay_in_seconds', 60*60*6, 'Number of seconds before sending email again.')
  Params.integer('validation_interval', 60*60*6, 'Number of seconds between validations')
  Params.integer('backup_time_requirement', 60*60,
                 'Max diff in seconds between timestamps of file indexation on master ' +
                 'and its content indexation on backup.' +
                 ' NOTE Machines must have time synchronization.')
end # module TestingServer
