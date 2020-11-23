#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
use t::APISIX 'no_plan';

repeat_each(1);
log_level('info');
worker_connections(256);
no_root_location();
no_shuffle();

run_tests();

__DATA__

=== TEST 1: set route(id: 1)
--- config
    location /t {
        content_by_lua_block {
            local t = require("lib.test_admin").test
            local code, body = t('/apisix/admin/routes/1',
                 ngx.HTTP_PUT,
                 [[{
                        "methods": ["GET"],
                        "upstream": {
                            "nodes": {
                                "127.0.0.1:1980": 1
                            },
                            "type": "roundrobin"
                        },
                        "uri": "/hello"
                }]]
                )

            if code >= 300 then
                ngx.status = code
            end
            ngx.say(body)
        }
    }
--- request
GET /t
--- response_body
passed
--- no_error_log
[error]



=== TEST 2: hit the route and status code is 200
--- request
GET /hello
--- response_body
hello world
--- no_error_log
[error]
--- grep_error_log eval
qr/X-Apisix-Upstream-Status:/
--- grep_error_log_out



=== TEST 3: set route(id: 1)
--- config
    location /t {
        content_by_lua_block {
            local t = require("lib.test_admin").test
            local code, body = t('/apisix/admin/routes/1',
                 ngx.HTTP_PUT,
                 [[{
                        "methods": ["GET"],
                        "upstream": {
                            "nodes": {
                                "127.0.0.1:1980": 1
                            },
                            "type": "roundrobin",
                            "timeout": {
                                "connect": 0.5,
                                "send": 0.5,
                                "read": 0.5
                            }
                        },
                        "uri": "/sleep1"
                }]]
                )

            if code >= 300 then
                ngx.status = code
            end
            ngx.say(body)
        }
    }
--- request
GET /t
--- response_body
passed
--- no_error_log
[error]



=== TEST 4: hit routes (timeout)
--- request
GET /sleep1
--- error_code: 504
--- response_body eval
qr/504 Gateway Time-out/
--- error_log
X-Apisix-Upstream-Status: 504 



=== TEST 5: set route(id: 1), upstream service is not available
--- config
    location /t {
        content_by_lua_block {
            local t = require("lib.test_admin").test
            local code, body = t('/apisix/admin/routes/1',
                 ngx.HTTP_PUT,
                 [[{
                        "methods": ["GET"],
                        "upstream": {
                            "nodes": {
                                "127.0.0.1:1": 1
                            },
                            "type": "roundrobin"
                        },
                        "uri": "/hello"
                }]]
                )

            if code >= 300 then
                ngx.status = code
            end
            ngx.say(body)
        }
    }
--- request
GET /t
--- response_body
passed
--- no_error_log
[error]



=== TEST 6: hit routes (502 Bad Gateway)
--- request
GET /hello
--- error_code: 502
--- response_body eval
qr/502 Bad Gateway/
--- error_log
X-Apisix-Upstream-Status: 502



=== TEST 7: set route(id: 1)
--- config
    location /t {
        content_by_lua_block {
            local t = require("lib.test_admin").test
            local code, body = t('/apisix/admin/routes/1',
                 ngx.HTTP_PUT,
                 [[{
                        "methods": ["GET"],
                        "upstream": {
                            "nodes": {
                                "127.0.0.1:1980": 1
                            },
                            "type": "roundrobin"
                        },
                        "uri": "/server_error"
                }]]
                )

            if code >= 300 then
                ngx.status = code
            end
            ngx.say(body)
        }
    }
--- request
GET /t
--- response_body
passed
--- no_error_log
[error]



=== TEST 8: hit routes(500 Internal Server Error)
--- request
GET /server_error
--- error_code: 500
--- response_body eval
qr/>500 Internal Server Error/
--- error_log
X-Apisix-Upstream-Status: 500



=== TEST 9: set route(id: 1), and bind the upstream_id
--- config
    location /t {
        content_by_lua_block {
            local t = require("lib.test_admin").test
            local code, body = t('/apisix/admin/routes/1',
                 ngx.HTTP_PUT,
                 [[{
                        "uri": "/hello",
                        "upstream_id": "1"
                }]]
                )

            if code >= 300 then
                ngx.status = code
            end
            ngx.say(body)
        }
    }
--- request
GET /t
--- response_body
passed
--- no_error_log
[error]



=== TEST 10: set upstream(id: 1, retries = 2), has available upstream
--- config
    location /t {
        content_by_lua_block {
            local t = require("lib.test_admin").test
            local code, body = t('/apisix/admin/upstreams/1',
                ngx.HTTP_PUT,
                [[{
                    "nodes": {
                        "127.0.0.3:1": 1,
                        "127.0.0.2:1": 1,
                        "127.0.0.1:1980": 1
                    },
                    "retries": 2,
                    "type": "roundrobin"
                }]]
                )

            if code >= 300 then
                ngx.status = code
            end
            ngx.say(body)
        }
    }
--- request
GET /t
--- response_body
passed
--- no_error_log
[error]



=== TEST 11: hit routes, status code is 200
--- request
GET /hello
--- grep_error_log eval
qr/X-Apisix-Upstream-Status:/
--- grep_error_log_out



=== TEST 12: set upstream(id: 1, retries = 2), all upstream nodes are unavailable
--- config
    location /t {
        content_by_lua_block {
            local t = require("lib.test_admin").test
            local code, body = t('/apisix/admin/upstreams/1',
                ngx.HTTP_PUT,
                [[{
                    "nodes": {
                        "127.0.0.3:1": 1,
                        "127.0.0.2:1": 1,
                        "127.0.0.1:1": 1

                    },
                    "retries": 2,
                    "type": "roundrobin"
                }]]
                )

            if code >= 300 then
                ngx.status = code
            end
            ngx.say(body)
        }
    }
--- request
GET /t
--- response_body
passed
--- no_error_log
[error]



=== TEST 13: hit routes, retries failed, status code is 502
--- request
GET /hello
--- error_code: 502
--- grep_error_log eval
qr/X-Apisix-Upstream-Status: 502/
--- grep_error_log_out
X-Apisix-Upstream-Status: 502



=== TEST 14: the status code returned from apisix
--- config
    location /t {
        content_by_lua_block {
            ngx.exit(500)
        }
    }
--- request
GET /t
--- error_code: 500
--- grep_error_log eval
qr/X-Apisix-Upstream-Status:/
--- grep_error_log_out



=== TEST 15: the status code returned from apisix
--- config
    location /t {
        content_by_lua_block {
            ngx.exit(502)
        }
    }
--- request
GET /t
--- error_code: 502
--- grep_error_log eval
qr/X-Apisix-Upstream-Status:/
--- grep_error_log_out
