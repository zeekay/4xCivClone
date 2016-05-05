require 'shortcake'

use 'cake-test'
use 'cake-publish'
use 'cake-version'

fs        = require 'fs'
requisite = require 'requisite'

option '-b', '--browser [browser]', 'browser to use for tests'
option '-g', '--grep [filter]',     'test filter'
option '-t', '--test [test]',       'specify test to run'
option '-v', '--verbose',           'enable verbose test logging'

task 'clean', 'clean project', ->
  exec 'rm -rf public/release'

task 'build', 'build project', (cb) ->
  yield exec '''
    coffee -c -o lib/ src/
    rm -rf release
    mkdir release
    mkdir release/public
    mkdir release/public/vendor

    cp -r assets release/public/assets
    cp index.html release/public/index.html
    cp build/cocos2d-built.js release/public/cocos2d.js
    cp -r vendor/random release/public/vendor/random

    cat vendor/cocos2d-html5/lib/Cocos2d-html5-v2.1.1.min.js lib/World.js lib/Async.js lib/Background.js lib/CustomSprites.js lib/Engine.js lib/Overlay.js lib/patches.js lib/SpatialHash.js > release/public/gamemerged.js
    uglifyjs release/public/gamemerged.js > release/public/game.js

    uglifyjs main.js > release/public/main.js && rm -f release/public/gamemerged.js
    uglifyjs config.js > release/public/config.js

    cp build/index.js release/index.js
    cp build/package.json release/package.json
    cp build/README.md release/README.md
    cp build/Procfile release/Procfile
    ''', cwd: 'public/'

task 'build-min', 'build project', ['build'], ->

task 'server', 'run server', ->
  yield exec 'bebop public/release/public'

task 'watch', 'watch for changes and recompile project', ->
  exec 'coffee -bcmw -o public/lib/ public/src/'
