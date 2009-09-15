#!/usr/bin/env ruby

base = File.basename(Dir.pwd)
if base == 'tests' || base =~ /file-tail/
	Dir.chdir('..') if base == 'tests'
	$LOAD_PATH.unshift(File.join(Dir.pwd, 'lib'))
end

require 'test/unit'
require 'file/tail'
require 'tempfile'
require 'timeout'
require 'thread'
Thread.abort_on_exception = true

class TC_FileTail < Test::Unit::TestCase
  include File::Tail

  def setup
    @out = File.new("test.#$$", "wb")
    append(@out, 100)
    @in = File.new(@out.path, "rb")
    @in.extend(File::Tail)
    @in.interval            = 0.4
    @in.max_interval        = 0.8
    @in.reopen_deleted      = true # is default
    @in.reopen_suspicious   = true # is default
    @in.suspicious_interval  = 60
  end

  def test_forward
    [ 0, 1, 2, 10, 100 ].each do |lines|
      @in.forward(lines)
      assert_equal(100 - lines, count(@in))
    end
    @in.forward(101)
    assert_equal(0, count(@in))
  end

  def test_backward
    [ 0, 1, 2, 10, 100 ].each do |lines|
      @in.backward(lines)
      assert_equal(lines, count(@in))
    end
    @in.backward(101)
    assert_equal(100, count(@in))
  end

  def test_tail_with_block_without_n
    timeout(10) do
      lines = []
      @in.backward(1)
      assert_raises(TimeoutError) do
        timeout(1) { @in.tail { |l| lines << l } }
      end
      assert_equal(1, lines.size)
      #
      lines = []
      @in.backward(10)
      assert_raises(TimeoutError) do
        timeout(1) { @in.tail { |l| lines << l } }
      end
      assert_equal(10, lines.size)
      #
      lines = []
      @in.backward(100)
      assert_raises(TimeoutError) do
        timeout(1) { @in.tail { |l| lines << l } }
      end
      assert_equal(100, lines.size)
      #
      lines = []
      @in.backward(101)
      assert_raises(TimeoutError) do
        timeout(1) { @in.tail { |l| lines << l } }
      end
    end
  end

  def test_tail_with_block_with_n
    timeout(10) do
      @in.backward(1)
      lines = []
      timeout(1) { @in.tail(0) { |l| lines << l } }
      assert_equal(0, lines.size)
      #
      @in.backward(1)
      lines = []
      timeout(1) { @in.tail(1) { |l| lines << l } }
      assert_equal(1, lines.size)
      #
      @in.backward(10)
      lines = []
      timeout(1) { @in.tail(10) { |l| lines << l } }
      assert_equal(10, lines.size)
      #
      @in.backward(100)
      lines = []
      @in.backward(1)
      assert_raises(TimeoutError) do
        timeout(1) { @in.tail(2) { |l| lines << l } }
      end
      assert_equal(1, lines.size)
      #
    end
  end

  def test_tail_without_block_with_n
    timeout(10) do
      @in.backward(1)
      lines = []
      timeout(1) { lines += @in.tail(0) }
      assert_equal(0, lines.size)
      #
      @in.backward(1)
      lines = []
      timeout(1) { lines += @in.tail(1) }
      assert_equal(1, lines.size)
      #
      @in.backward(10)
      lines = []
      timeout(1) { lines += @in.tail(10) }
      assert_equal(10, lines.size)
      #
      @in.backward(100)
      lines = []
      @in.backward(1)
      assert_raises(TimeoutError) do
        timeout(1) { lines += @in.tail(2) }
      end
      assert_equal(0, lines.size)
    end
  end

  def test_tail_withappend
    @in.backward
    lines = []
    threads = []
    threads << Thread.new do
      begin
        timeout(1) { @in.tail { |l| lines << l } }
      rescue TimeoutError
      end
    end
    threads << Thread.new { append(@out, 10) }
    threads.collect { |t| t.join }
    assert_equal(10, lines.size)
  end

  def test_tail_truncated
    @in.backward
    lines = []
    threads = []
    threads << appender = Thread.new do
      Thread.stop
      @out.close
      File.truncate(@out.path, 0)
      @out = File.new(@in.path, "ab")
      append(@out, 10)
    end
    threads << Thread.new do
      begin
        timeout(1) do
          @in.tail do |l|
            lines << l
            lines.size == 100 and appender.wakeup
          end
        end
      rescue TimeoutError
      end
    end
    threads.collect { |t| t.wakeup and t.join }
    assert_equal(10, lines.size)
  end

  def test_tail_remove
		return if File::PATH_SEPARATOR == ';' # Grmpf! Windows...
    @in.backward
		reopened = false
		@in.after_reopen { |f| reopened = true }
    lines = []
    threads = []
    threads << appender = Thread.new do
      Thread.stop
      @out.close
      File.unlink(@out.path)
      @out = File.new(@in.path, "wb")
      append(@out, 10)
    end
    threads << Thread.new do
      begin
        timeout(2) do
          @in.tail do |l|
            lines << l
            lines.size == 100 and appender.wakeup
          end
        end
      rescue TimeoutError
      end
    end
    threads.collect { |t| t.wakeup and t.join }
    assert_equal(10, lines.size)
		assert reopened
  end

  def test_tail_remove2
		return if File::PATH_SEPARATOR == ';' # Grmpf! Windows...
    @in.backward
		reopened = false
		@in.after_reopen { |f| reopened = true }
    lines = []
    threads = []
    threads << appender = Thread.new do
      Thread.stop
      @out.close
      File.unlink(@out.path)
      @out = File.new(@in.path, "wb")
      append(@out, 10)
			sleep 1
      append(@out, 10)
      File.unlink(@out.path)
      @out = File.new(@in.path, "wb")
      append(@out, 10)
    end
    threads << Thread.new do
      begin
        timeout(2) do
          @in.tail do |l|
            lines << l
            lines.size == 100 and appender.wakeup
          end
        end
      rescue TimeoutError
      end
    end
    threads.collect { |t| t.wakeup and t.join }
    assert_equal(30, lines.size)
		assert reopened
  end

  def test_tail_remove3
		return if File::PATH_SEPARATOR == ';' # Grmpf! Windows...
    @in.backward
		reopened = false
		@in.after_reopen { |f| reopened = true }
    lines = []
    threads = []
    threads << appender = Thread.new do
      Thread.stop
      @out.close
      File.unlink(@out.path)
      @out = File.new(@in.path, "wb")
      append(@out, 10)
			sleep 1
      append(@out, 10)
      File.unlink(@out.path)
      @out = File.new(@in.path, "wb")
      append(@out, 10)
    end
    threads << Thread.new do
      begin
        timeout(2) do
          @in.tail(15) do |l|
            lines << l
            lines.size == 100 and appender.wakeup
          end
        end
      rescue TimeoutError
      end
    end
    threads.collect { |t| t.wakeup and t.join }
    assert_equal(15, lines.size)
		assert reopened
  end

  def teardown
    @in.close
    @out.close
		File.unlink(@out.path)
  end

  private

  def count(file)
    n = 0
    until file.eof?
      file.readline
      n += 1
    end
    return n
  end

  def append(file, n)
    (1..n).each { |x| file << "#{x} #{"A" * 70}\n" }
    file.flush
  end
end
  # vim: set noet sw=2 ts=2:
