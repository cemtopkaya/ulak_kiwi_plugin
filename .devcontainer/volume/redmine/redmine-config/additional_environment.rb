#Logger.new(PATH,NUM_FILES_TO_ROTATE,FILE_SIZE)
#config.logger = Logger.new('/usr/src/redmine/log/redmine.log', 5, 1000000)
config.logger = Logger.new(STDOUT)
config.logger.level = Logger::DEBUG
