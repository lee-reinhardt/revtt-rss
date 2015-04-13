#!/usr/bin/env python

import json, requests, re, random, os, syslog
from bs4 import BeautifulSoup

class RevttRss:
    def __init__(self):
        self.path    = os.path.expanduser('~') + '/.revtt-rss'
        self.good    = None
        self.bad     = None
        self.history = None

        syslog.openlog('revttrss', logoption=syslog.LOG_PID, facility=syslog.LOG_LOCAL0)

        self.load_config()

    def load_config(self):
        with open(self.path + '/config.json') as config:
            self.config = json.load(config)

        self.save_dir    = self.config['save_dir']
        self.passkey     = self.config['passkey']
        self.categories  = self.config['categories']
        self.password    = self.config['pass']
        self.uid         = self.config['uid']
        self.max_history = self.config['max_history'] if 'max_history' in self.config else 25

    def run(self):
        url     = 'https://revolutiontt.me/rss.php?feed=dl&cat={0}&passkey={1}'.format(self.categories, self.passkey)
        cookies = {'pass': self.password, 'uid': self.uid}

        r = requests.get(url, cookies=cookies)

        if r.status_code is not 200:
            raise Exception('Bad status code "{0}" from site', r.status_code)

        self.load_shows()
        self.process(r.text)

    def process(self, text):
        xml = BeautifulSoup(text)

        for t in xml.find_all('item'):
            title = t.title.get_text()

            if self.is_good(title) and not self.is_bad(title) and not self.in_history(title):
                syslog.syslog('downloading {0}'.format(title))

                self.download(t)
                self.add_to_history(title)

        if random.randint(1,25) == 7:
            self.prune_history()


    def load_shows(self):
        with open(self.path + '/good.txt', 'r') as good:
            self.good = good.read().splitlines()

        with open(self.path + '/bad.txt', 'r') as bad:
            self.bad = bad.read().splitlines()

        with open(self.path + '/history.txt', 'r') as history:
            self.history = history.read().splitlines()

    def is_good(self, name):
        for show in self.good:
            result = re.match(show, name)

            if result is not None:
                return True

        return False

    def is_bad(self, name):
        for show in self.bad:
            result = re.match(show, name)

            if result is not None:
                return True

        return False

    def in_history(self, name):
        for show in self.history:
            result = re.match(show, name)

            if result is not None:
                return True

        return False

    def prune_history(self):
        syslog.syslog('pruning history')

        with open(self.path + '/history.txt', 'r+') as history:
            lines  = history.read().splitlines()
            length = len(lines)

            if length < self.max_history:
                syslog.syslog('pruning: not long enough to prune')
                return

            syslog.syslog('pruning: trimming {0} lines to {1}'.format(str(length), str(self.max_history)))

            start = length - self.max_history
            end   = start + self.max_history + 1

            history.seek(0)
            history.truncate()
            history.writelines('\n'.join(lines[start:end]))

    def add_to_history(self, name):
        self.history.append(name)

        with open(self.path + '/history.txt', 'r+') as history:
            history.seek(0)
            history.truncate()
            history.writelines('\n'.join(self.history))

    def download(self, item):
        link      = item.link.get_text()
        title     = item.title.get_text()
        filename  = '{0}.torrent'.format(title)
        file_path = '{0}/{1}'.format(self.save_dir, filename)

        r = requests.get(link, stream=True)

        with open(file_path, 'wb') as f:
            for chunk in r.iter_content(chunk_size=1024):
                if chunk: # filter out keep-alive new chunks
                    f.write(chunk)
                    f.flush()
        return title

def main():
    r = RevttRss()
    try:
        r.run()
    except Exception as e:
        syslog.syslog(syslog.LOG_ERR, 'exception while processing\n{0}'.format(e))

if __name__ == "__main__":
    main()