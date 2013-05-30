require 'content_server/content_server'
require 'content_server/backup_server'

module ContentServer
  # Flags combined for content and backup server.
  Params.path('local_content_data_path', '', 'ContentData file path.')

  # Monitoring
  Params.boolean('enable_monitoring', false, 'Whether to enable process monitoring or not.')

  # Handling thread exceptions.
  Params.boolean('abort_on_exception', true, 'Any exception in any thread will abort the run.')

  Params.integer('data_flush_delay', 300, 'Number of seconds to delay content data file flush to disk.')

end # module ContentServer
