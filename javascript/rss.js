#!/usr/bin/env node

(function() {

  Array.prototype.remove = function(from, to) {
    var rest = this.slice((to || from) + 1 || this.length);
    this.length = from < 0 ? this.length + from : from;
    return this.push.apply(this, rest);
  };

  var _      = require('lodash');
  var fs     = require('fs');
  var klass  = require('klass');
  var https  = require('https');
  var xml2js = require('xml2js');
  var syslog = require('node-syslog');

  syslog.init('revttrss', syslog.LOG_PID | syslog.LOG_ODELAY, syslog.LOG_LOCAL0);

  var log = {
    info: function (msg) {
      syslog.log(syslog.LOG_INFO, msg);
    },

    error: function (msg) {
      syslog.log(syslog.LOG_ERR, msg);
    }
  };

  var RevttRss = klass({
    path:    process.env['HOME'] + '/.revtt-rss',
    good:    null,
    bad:     null,
    history: null,
    config:  {},

    initialize: function () {
      this.loadConfig();
      this.loadShows();
    },

    run: function () {
      var self = this,
          body = '',
          opts = {
            hostname: 'revolutiontt.me',
            path: '/rss.php?feed=dl&cat=' + this.config.categories + '&passkey=' + this.config.passkey,
            headers: {
              'Cookie': 'pass=' + this.config.pass + '; uid=' + this.config.uid
            }
          };

      var req = https.request(opts, function (res) {
        // log.info('http request, status:' + res.statusCode);
        // log.info('http request, headers: ' + JSON.stringify(res.headers));
        res.on('data', function (chunk) { body += chunk; });
        res.on('end', function () { self.process(body); });
      });

      req.on('error', function (e) {
        log.error('xml request failed ' + e.message)
        throw e.message
      });

      req.end();
    },

    loadConfig: function () {
      this.config = JSON.parse(
        fs.readFileSync(this.path + '/config.json', 'utf8')
      );
    },

    loadShows: function () {
      this.bad     = fs.readFileSync(this.path + '/bad.txt', 'utf8').split('\n');
      this.good    = fs.readFileSync(this.path + '/good.txt', 'utf8').split('\n');
      this.history = fs.readFileSync(this.path + '/history.txt', 'utf8').split('\n');
    },

    process: function (body) {
      var self = this;

      xml2js.parseString(body, function (err, result) {
        if(err) throw 'failed to parse xml. err: ' + err;

        var items = result.rss.channel[0].item

        _.each(items, function (item) {
          var title = item.title[0];
          var link  = item.link[0];

          if(!title || !link) return;

          if( self.is('good', title) && ! self.is('bad', title) && ! self.is('history', title) ) {
            log.info('downloading ' + title);

            self.download(title, link, self.addToHistory.bind(self))
          }
        });
      });
    },

    is: function (type, title) {
      for (var i in this[type]) {
        try {
          var re = new RegExp(this[type][i]);
          if(re.test(title)) return true;
        } catch(e) {}
      }

      return false;
    },

    download: function (title, link, cb) {
      var savePath = this.config.save_dir + '/' + title + '.torrent',
          file     = fs.createWriteStream(savePath);

      var req = https.get(link, function (res) {
        res.pipe(file);

        file.on('finish', function () {
          file.close(cb(title));
        });
      });

      req.on('error', function (e) {
        log.error('download request failed ' + e.message)
        throw e.message
      });

      req.end();
    },

    addToHistory: function (title) {
      var self = this;

      fs.appendFile(this.path + '/history.txt', '\n' + title, function (err) {
        if(err) throw err;
        if(parseInt(Math.random()*20|0) === 7) self.pruneHistory();
      });
    },

    pruneHistory: function () {
      var history = fs.readFileSync(this.path + '/history.txt', 'utf8').split('\n');

      if(!history || history.length == 0) {
        log.error('failed to open history');
        return;
      }

      if(history.length <= this.config.max_history) {
        log.info('pruning: not long enough to prune');
        return;
      }

      log.info('pruning: trimming ' + history.length + ' to ' + this.config.max_history);

      var overage = history.length - this.config.max_history;

      history.remove(0, overage);

      var contents = history.join('\n');

      fs.writeFileSync(this.path + '/history.txt', contents, {flag: 'w+'});
    }

  });

  var rss = new RevttRss({});
  rss.run();
})();