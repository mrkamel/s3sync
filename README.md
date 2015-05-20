
# s3sync

s3sync is a low-memory, highly parallelizable (via prefixes) s3 client that
syncs a bucket to a local filesystem.

## Setup

You need to have ruby installed on your system.
First, install bundler:

```
$ gem install bundler
```

Then, install s3sync's dependencies:

```
$ cd /path/to/s3sync
$ bundle
```

Create a config file, like e.g. config.yml:

```
endpoint: s3-eu-west-1.amazonaws.com
access_key: YOUR ACCESS KEY
secret_key: YOUR SECRET KEY
```

## Usage

```
$ ./s3sync --help
Usage: s3sync [options]
        --config PATH
        --bucket BUCKET
        --prefix PREFIX
        --path PATH
```

The most common way to use it is:

```
$ s3sync --config config.yml --bucket BUCKET --prefix PREFIX --path /path/to/destination
```

s3sync currently is a fetch only client, such that it will fetch all files matching the
bucket and optional prefix unless the file already exists on the local filesystem having
the same file size as on s3.

# Example

The strength of s3sync is that it works great when parallelized by starting it multiple
times (e.g. via threads) with disjoint prefixes:

```
$ s3sync --config config.yml --bucket BUCKET --prefix images/1 --path /path/to/destination
$ s3sync --config config.yml --bucket BUCKET --prefix images/2 --path /path/to/destination
$ s3sync --config config.yml --bucket BUCKET --prefix images/3 --path /path/to/destination
...
```

To run it in parallel via your own ruby scripts, you can use something similar to:

```ruby
require "thread"

def in_parallel(collection, n)
  queue = Queue.new

  collection.each { |element| queue.push element }

  threads = []

  n.times do
    threads << Thread.new do
      begin
        until queue.empty?
          yield queue.pop(true)
        end
      rescue ThreadError => e
        # Queue empty
      end
    end
  end

  threads.each &:join
end

prefixes = (1 .. 9).to_a

in_parallel prefixes, 5 do |prefix|
  system "/path/to/s3sync", "--config", "/path/to/config.yml", "--bucket", "BUCKET", "--prefix", "images/#{prefix}", "--path", "/path/to/destination"
end
```

