# revtt-rss

Scripts for auto-downloading torrents via the RevolutionTT RSS feed. Implemented in a variety of languages for convenience, but mostly as personal programming exercises.

## Install

Clone and setup config files.

```
$ git clone https://github.com/lee-reinhardt/revtt-rss.git
$ cd revtt-rss
$ cp -r .revtt-rss ~
```

## Configure

### config.json

Update `~/.revtt-rss/config.json` with your account values.

option         | description
-------------- | --------------
`uid`          | User ID.
`pass`         | Cookie auth pass.
`passkey`      | Tracker torrent passkey.
`categories`   | Comma-separated list of category IDs.
`save_dir`     | Full path to torrent file download directory.
`max_history`  | Maximum number of files to keep in `history.txt`.

To find your `passkey` and assemble a personalized `categories` string, log in, and visit `/getrss.php`. To find your `uid` and `pass` check your site cookies.

### {good,bad,history}.txt
These three files contain regexes describing files you want (`good.txt`), do not want (`bad.txt`), and have already downloaded (`history.txt`). Each entry should be separated by a newline.

See the following examples.

#### good.txt

```
Game\.[Oo]f\.Thrones.+720p.+[xX]264.+
South\.Park.+720p.+[xX]264.+
The\.Big\.Bang\.Theory.+720p.+[xX]264.+
Archer.+720p.+[xX]264.+
```

#### bad.txt

```
.+1080p\.HDTV.+
.+DD5.+
.+[Ii]NTERNAL.+
```

# Languages

* All scripts read config files from `~/.revtt-rss`.
* All scripts log to syslog with the name `revttrss`.

## Python

Ensure you have [pip](https://pip.pypa.io/en/latest/installing.html) installed.

```
$ cd revtt-rss/python
$ pip install -r requirements.txt
$ python rss.py
```

## Ruby

Ensure you have [bundler](http://bundler.io/) installed.

```
$ cd revtt-rss/ruby
$ bundle install
$ ruby rss.rb
```

## JavaScript

Ensure you have [nodejs](https://nodejs.org/) installed.

```
$ cd revtt-rss/javascript
$ npm install
$ node rss.js
```

## Perl

```
@todo
```

## Go

```
@todo
```


## Crontab

```
$ crontab -e
# run the script every minute
* * * * * python /home/user/revtt-rss/python/rss.py 2>&1
# or
* * * * * ruby   /home/user/revtt-rss/ruby/rss.rb 2>&1
# or
* * * * * node   /home/user/revtt-rss/javascript/rss.js 2>&1

```

## Credits

Based on the original Perl script written by RevTT user *deadhead*.