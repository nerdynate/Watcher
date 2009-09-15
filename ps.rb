require 'rubygems'
require 'dbi'

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

get_processlist
