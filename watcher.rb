require 'rubygems'
require 'daemonize'
require 'file/tail'
require 'dbi'
require 'net/smtp'

files   = %w{/tmp/log1.txt /tmp/log2.txt /tmp/log3.txt}
pattern = "cannot connect"

class Watcher
  include Daemonize

  def initialize(files, pattern)
    @files   = files
    @pattern = pattern
    #for testing
    @logfile = '/tmp/logfile.txt'
  end

  def start()
    #daemonize()
    block_on_watchers(start_watchers(@pattern, @files))
  end

  def get_processlist()
    fh   = File.new('/tmp/psfile.txt', 'w')
    dsn  = 'DBI:Mysql:gshark_db:172.16.0.17'
    dbh  = DBI.connect(dsn, 'gsharkmy', 'n0ttehr00t!!')
    sql  = 'SHOW FULL PROCESSLIST'
    sth  = dbh.prepare(sql)
    sth.execute
    while row = sth.fetch
        fh.puts(row)
    end
  end  

  def email_log(logfile)
    message = <<-MESSAGE_END
    From: Nate <nate.geouge@escapemg.com>
    To: Nate <nate.geouge@escapemg.com>
    Subject: MySQL Process List of Doom
   
    This should have the error log file in it.
    MESSAGE_END

    Net::SMTP.start('localhost') do |smtp|
       smtp.send_message message, 'nate@escapemg.com', 
                               'nate.geouge@escapemg.com'
    end
  end

  def start_scanner(pattern, filename, &callback)
    while !File.exists?(filename)
      sleep(1)
    end

    while true
      File.open(filename) do |log|
        log.seek(IO::SEEK_END)
        log.extend(File::Tail)
        log.interval = 0.25
        log.backward(0)
        log.tail do |line|
          if line =~ /#{pattern}/i
            if block_given?
              callback.call(filename, line)
              break
            end
          end
        end
      end
    end
  end

  def print_filename(filename, line)
    puts "#{filename}: #{line}"
  end

  def start_watchers(pattern, files)
    threads = []
    files.each do |file|
      threads << Thread.new do
        start_scanner(pattern, file) do |filename, line|
          # begin critical section (all other threads are stopped)
          Thread.critical = true
          print_filename(filename, line)       
          get_processlist
          email_log(@logfile)
          sleep 10
          Thread.critical = false
          # end critical section (other threads resume)
        end
      end
    end
    return threads
  end

  def block_on_watchers(threads)
    threads.each do |thread|
      thread.join
    end
  end
end

watcher = Watcher.new(files, pattern)
watcher.start
