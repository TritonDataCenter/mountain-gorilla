/*
 * Copyright 2014 Joyent, Inc.  All rights reserved.
 *
 * Main CLI for sdc-jenkins tool.
 */

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
var vasync = require('vasync');


//---- globals

var p = console.log;



//---- internal support stuff

function shellEscape(s) {
    return s.replace(/'/g, "'\\''");
}



//---- the CLI "App"

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
                help: 'Configuration JSON file. ' +
                    'Must contain keys: user, pass, host. ' +
                    'Default is "~/.sdcjenkins".'
            }
        ]
    });
}
util.inherits(App, cmdln.Cmdln);


App.prototype.do_ssh_config = function (subcmd, opts, args, callback) {
    var self = this;
    var nodes = [];

    var infos = {}, mdata, labels;

    self.initialize();

    async.waterfall([
        getNodeList,
        getNodesSystemInfo
    ],
    function (err) {
        if (err) {
            console.warn(err.message);
            return;
        }

        var items = [];

        nodes.forEach(function (n) {
            var item = {
                name: n,
                ip: (infos[n] &&
                     infos[n].JENKINS_IP_ADDR)
            };

            if (!item.ip) {
                console.warn('Error: no IP address for %s', n);
                return;
            }
            console.log(sprintf(
                'Host %s\n'
              + '    Hostname %s\n'
              + '    User root\n'
              + '    StrictHostKeyChecking no\n'
              + '    UserKnownHostsFile /dev/null\n', n, item.ip));
        });

        callback();
    });

    function getNodeList(cb) {
        if (args.length) {
            nodes = args;
            nodes.sort();
        } else {
            self.jc.node.list(function (err, l) {
                if (err) {
                    cb(err);
                    return;
                }

                nodes = l.computer.map(function (i) { return i.displayName; });
                nodes.sort();
                cb();
            });
        }
    }

    function getNodesSystemInfo(cb) {
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
        self.getNodesMdata(nodes, function (err, nodeMdata) {
            if (err) {
                cb(err);
                return;
            }
            mdata = nodeMdata;

            cb();
        });
    }
};


App.prototype.do_ssh_config.help = 'Generate SSH config for given Jenkins nodes with defined addresses';


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

//         cb(); return;

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



App.prototype.do_oneachnode = function do_oneachnode(subcmd, opts, args, cb) {
    var self = this;
    if (opts.help) {
        this.do_help('help', {}, [subcmd], cb);
        return;
    } else if (args.length !== 1) {
        return cb(new Error('incorrect number of args: ' + args));
    }

    self.initialize();
    var SSH = 'ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -l root';
    var cmd = args[0];
    var computers;
    var results = [];

    vasync.pipeline({funcs: [
        function getComputers(_, next) {
            self.jc.node.list(function (err, nodes) {
                if (err) {
                    return next(err)
                }
                computers = nodes.computer;
                next();
            });
        },

        function trim(_, next) {
            var trimmed = computers.filter(function (c) {
                return (self.blacklist.indexOf(c.displayName) === -1);
            });
            computers = trimmed;
            next();
        },

        function run(_, next) {
            vasync.forEachParallel({
                inputs: computers,
                func: function runOne(computer, next2) {
                    exec(
                        format("%s %s '%s'", SSH, computer.displayName,
                            shellEscape(cmd)),
                        {timeout: 5000},
                        function (err, stdout, stderr) {
                            results.push({
                                computer: computer.displayName,
                                result: {
                                    err: err,
                                    exit_status: (err ? err.code : 0),
                                    stdout: stdout,
                                    stderr: stderr
                                }
                            });
                            next2();
                        }
                    );
                }
            }, next);
        },

        function display(_, next) {
            tabula.sortArrayOfObjects(results, ['computer']);
            if (opts.json) {
                p(JSON.stringify(results, null, 4));
            } else if (opts.jsonstream) {
                for (var i = 0; i < results.length; i++) {
                    p(JSON.stringify(results[i]));
                }
            } else {
                var table = [];
                var singleLineOutputs = true;
                for (var i = 0; i < results.length; i++) {
                    var computer = results[i].computer;
                    var result = results[i].result;
                    var output;
                    if (result.err && result.err.killed) {
                        output = format('<ERROR: timeout for computer %s>',
                            computer);
                    } else if (result.err && !result.stdout && !result.stderr) {
                        output = format('<ERROR: ssh to %s failed (update your ~/.ssh/config)>',
                            computer);
                    } else {
                        output = result.stdout;
                        if (output.length > 1 && output.slice(-1) === '\n') {
                            output = output.slice(0, output.length - 1);
                        }
                        if (result.stderr) {
                            if (output) {
                                output += '\n';
                            }
                            output += result.stderr;
                        }
                    }
                    if (output.trim().indexOf('\n') !== -1) {
                        singleLineOutputs = false;
                    }
                    table.push({computer: computer, output: output});
                }
                if (singleLineOutputs) {
                    tabula(table);
                } else {
                    for (var i = 0; i < table.length; i++) {
                        p("=== Output from", table[i].computer);
                        p(table[i].output);
                        if (table[i].output.slice(-1) !== '\n') {
                            p();
                        }
                    }
                }
            }
        }
    ]}, function (err) {
        cb(err);
    });
};
App.prototype.do_oneachnode.options = [
    {
        names: ['help', 'h'],
        type: 'bool',
        help: 'Show this help.'
    },
    {
        names: ['json', 'j'],
        type: 'bool',
        help: 'JSON output'
    },
    {
        names: ['jsonstream', 'J'],
        type: 'bool',
        help: 'JSON stream output'
    },
];
App.prototype.do_oneachnode.help = (
    'Run the given command on each SDC jenkins slave.\n'
    + '\n'
    + 'Usage:\n'
    + '     {{name}} oneachnode [<options>] <cmd>\n'
    + '\n'
    + '{{options}}\n'
    + 'This skips the "master" and pkgsrc pbulk nodes.\n'
);


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
            request(url, { rejectUnauthorized: false }, function (error, response, body) {
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

            exec('ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -l root ' + node +
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

            exec('ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 31337 jenkins.joyent.us get-node ' + node,
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
