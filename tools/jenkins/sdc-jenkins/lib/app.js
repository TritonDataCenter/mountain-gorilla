var cmdln = require('cmdln');
var fs = require('fs');
var util = require('util');
var format = util.format;
var sprintf = require('sprintf').sprintf;
var request = require('request');
var cheerio = require('cheerio');

var jenkins = require('jenkins');
var assert = require('assert-plus');
var async = require('async');
var tabula = require('tabula');
var exec = require('child_process').exec;
var spawn = require('child_process').spawn;

function App() {
    this.blacklist = ['master', 'pkgsrc-pbulk-master'];

    cmdln.Cmdln.call(this, {
        name: 'sdc-jenkins',
        desc: 'SDC Jenkins Multitool',
        options: [
            {
                names: ['config', 'c'],
                helpArg: 'FILE',
                type: 'string',
                default: process.env.HOME + '/.sdcjenkins',
                help:
                    'Configuration JSON file. ' +
                    'Must contain keys: user, pass, host.'
            }
        ]
    });
}

util.inherits(App, cmdln.Cmdln);


App.prototype.do_create_node = function (subcmd, opts, args, callback) {

    var params = [ args[0] ];

    if (opts.image) {
        params.push(opts.image);
    }

    var spawnArgs = [
        __dirname + '/../create-jenkins-slave/copy-and-start.sh',
        params,
        {
            env: {
                JENKINS_USER: opts.jenkins_user
            }
        } ,
        function (error, stdout, stderr) {
            if (error) {
                console.warn('ERROR:');
                callback(error);
                return;
            }

            callback();
        }
    ];

    console.dir(spawnArgs);

    spawn.apply(null, spawnArgs);
};

App.prototype.do_create_node.help = 
    'Create a new SDC Jenkins node\n'
    + '\n'
    + 'Usage:\n'
    + '     {{name}} create-node [OPTIONS] node-name\n'
    + '\n'
    + '{{options}}';

App.prototype.do_create_node.options = [
    {
        names: ['jenkins-user', 'u'],
        helpArg: 'USER',
        type: 'string',
        default: 'guest',
        help: 'Jenkins user for jenkins-ssh-api access.'
    },
    {
        names: ['image', 'i'],
        helpArg: 'IMAGE',
        type: 'string',
        default: 'sdc-smartos-1.6.3',
        help: 'Name of image to be used for provisioning Jenkins node'
    }
];


App.prototype.do_nodes = function (subcmd, opts, args, callback) {
    var self = this;

    var list, infos = {}, mdata, labels;

    self.initialize();

    async.waterfall([
        getNodeList,
        getNodesSystemInfo,
        getNodesMdata,
        getNodeLabels
    ],
    function (err) {
        if (err) {
            console.warn(err.message);
            return;
        }
        var input = [];

        list.computer.forEach(function (i) {
            if (self.blacklist.indexOf(i.displayName) !== -1) {
                return;
            }

            var item = {
                name: i.displayName,
                ip: (infos[i.displayName] &&
                     infos[i.displayName].JENKINS_IP_ADDR),
                dc: mdata[i.displayName].datacenter_name,
                'package': mdata[i.displayName].package_name,
                image: mdata[i.displayName].image_uuid,
                server: mdata[i.displayName].server_uuid,
                pi: mdata[i.displayName].platform,
                labels: labels[i.displayName]
            };

            input.push(item);
        });

        var tabOptions = {
            columns: [
                'name', 'ip', 'dc', 'server', 'pi', 'image', 'package',
                'labels'],
            validFields: [
                'name', 'ip', 'dc', 'server', 'pi', 'image', 'package',
                'labels']
        };

        tabula(input, tabOptions);
    });

    function getNodeList(cb) {
        self.jc.node.list(function (err, l) {
            if (err) {
                cb(err);
                return;
            }

            list = l;
            cb();
        });
    }

    function getNodesSystemInfo(cb) {
        var nodes = list.computer.map(function (i) { return i.displayName; });

        cb(); return;


        self.getNodeSystemInfo(nodes, function (err, systemInfos) {
            if (err) {
                cb(err);
                return;
            }
            infos = systemInfos;

            cb();
        });
    }

    function getNodesMdata(cb) {
        var nodes = list.computer.map(function (i) { return i.displayName; });

        self.getNodesMdata(nodes, function (err, nodeMdata) {
            if (err) {
                cb(err);
                return;
            }
            mdata = nodeMdata;

            cb();
        });
    }

    function getNodeLabels(cb) {
        var nodes = list.computer.map(function (i) { return i.displayName; });

        self.getNodeLabels(nodes, function (err, nodeLabels) {
            if (err) {
                cb(err);
                return;
            }
            labels = nodeLabels;

            cb();
        });
    }
};

App.prototype.do_nodes.help = 'Return all Jenkins nodes (workers)';


App.prototype.initialize = function () {
    this.config = JSON.parse(fs.readFileSync(this.opts.config));
    this.jenkinsUrl = sprintf('https://%s:%s@%s',
        this.config.user, this.config.pass, this.config.host);

    this.jc = jenkins(this.jenkinsUrl);

    assert.string(this.config.user, 'options.user');
    assert.string(this.config.pass, 'options.pass');
    assert.string(this.config.host, 'options.host');
};


/*
 * HTML scrape the node environment variables from the Jenkins HTML off the
 * Jenkins admin site.
 */

App.prototype.getNodeSystemInfo = function (n, callback) {
    var self = this;
    var dict = {};

    var nodes = [];

    if (!Array.isArray(n)) {
        nodes.push(n);
    } else {
        nodes = n;
    }

    async.each(
        nodes,
        function (node, cb) {
            var url = sprintf(
                '%s/computer/%s/systemInfo', self.jenkinsUrl, node);
            if (self.blacklist.indexOf(node) !== -1) {
                cb();
                return;
            }
            request(url, function (error, response, body) {
                if (error) {
                    console.warn(error.message);
                    callback(error);
                    return;
                }

                var re = '<tr><td class="pane">(.*?)</td>\\s*'
                           + '<td[^>]+>(.*?)</td>\\s*</tr>';
                var m = body.match(new RegExp(re, 'g'));

                var $;

                for (var i = 1; i < m.length; i++) {
                    if (!dict[node]) {
                        dict[node] = {};
                    }

                    $ = cheerio.load(m[i]);
                    var key = $('tr > td').eq(0).text();
                    var value = $('tr > td').eq(1).text();

                    dict[node][key] = value;
                }

                cb();
            });
        },
        function (err) {
            if (err) {
                callback(err);
                return;
            }

            callback(null, dict);
        });
};


/*
 * HTML scrape the node environment variables from the Jenkins HTML off the
 * Jenkins admin site.
 */

App.prototype.getNodesMdata = function (n, callback) {
    var self = this;
    var dict = {};

    var nodes = [];

    if (!Array.isArray(n)) {
        nodes.push(n);
    } else {
        nodes = n;
    }

    async.each(
        nodes,
        function (node, cb) {
            if (self.blacklist.indexOf(node) !== -1) {
                cb();
                return;
            }

            var vals = [
                'sdc:image_uuid',
                'sdc:server_uuid',
                'sdc:package_name',
                'sdc:datacenter_name'
            ];

            exec('ssh ' + node +
                 ' \'for i in ' + vals.join(' ') +
                 '; do mdata-get $i || echo "-"; done; sysinfo |json "Live Image"\'',
                 { timeout: 5000 },
                 function (err, stdout, stderr) {
                     if (!dict[node]) {
                         dict[node] = {};
                     }

                     if (err) {
                         console.warn(err.message);
                         dict[node].image_uuid = '!';
                         dict[node].server_uuid = '!';
                         dict[node].datacenter_name = '!';
                         dict[node].platform = '!';
                         dict[node].package_name = '!';
                         cb();
                         return;
                     }

                     var parts = stdout.trim().split('\n');

                     dict[node].image_uuid = parts[0];
                     dict[node].server_uuid = parts[1];
                     dict[node].package_name = parts[2];
                     dict[node].datacenter_name = parts[3];
                     dict[node].platform = parts[4];

                     cb();
                });
        },
        function (err) {
            callback(err, dict);
        });
};

App.prototype.getNodeLabels = function (n, callback) {
    var self = this;
    var dict = {};

    var nodes = [];

    if (!Array.isArray(n)) {
        nodes.push(n);
    } else {
        nodes = n;
    }

    async.each(
        nodes,
        function (node, cb) {
            if (self.blacklist.indexOf(node) !== -1) {
                cb();
                return;
            }

            exec('ssh jenkins-ssh-api get-node ' + node,
                 { timeout: 5000 },
                 function (err, stdout, stderr) {
                     var re = '<label>(.*)</label>';
                     var m = (new RegExp(re, 'g')).exec(stdout.toString());

                     if (!dict[node]) {
                         dict[node] = {};
                     }

                     if (!m) {
                         console.log(stdout);
                     }
                     dict[node] = m[1];

                     cb();
                     return;
                 });
        },
        function (err) {
            callback(err, dict);
        });
};

module.exports = App;
