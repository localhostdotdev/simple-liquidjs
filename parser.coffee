#!/usr/bin/env coffee

# imports

spawnSync = require('child_process').spawnSync
path = require('path')
fs = require('fs')
process = require('process')
minimist = require('minimist')

_ = require('underscore')
color = require('kleur')

peg = require('pegjs')
Tracer = require('pegjs-backtrace')

ROOT = __dirname

# lib

u = {}

u.json = (obj) ->
  JSON.stringify(obj, null, 2)

u.isColored = =>
  typeof ARGV.colored != "boolean" || ARGV.colored == true

u.log = (string) =>
  string = JSON.stringify(string) unless typeof string == "string"
  console.error(string)

u.error = (string) =>
  string = JSON.stringify(string) unless typeof string == "string"

  if u.isColored()
    console.error(color.red(string))
  else
    console.error(string)

# argv

ARGV = minimist(process.argv.slice(2),
  strings: ['grep', 'node-type', 'hidden-paths']
  boolean: ['colored', 'debug']
  default: {
    colored: true
    debug: false
    grep: ""
    'hidden-paths': ""
    'node-type': ""
  }
)

options = [
  '_', 'colored', 'debug', 'grep',
  'hidden-paths', 'node-type'
]

extra_options = _(_.keys(ARGV)).without(...options)

if _.any(extra_options) || ARGV._.length > 1
  u.error("unrecognized options #{extra_options.join(', ')}")
  u.error("\nUSAGE: parser [OPTIONS] INPUT")
  u.error("\n  options: #{options.join(', ')}")
  u.error("\n  defaults to stdin")
  process.exit(1)

ARGV.debug = true if ARGV.grep != "" || ARGV['node-type'] != ""

ARGV.source = ARGV._.join(' ')

unless process.stdin.isTTY
  ARGV.source += fs.readFileSync(0).toString().trim()

if ARGV.source != "" and fs.existsSync(ARGV.source)
  ARGV.source = fs.readFileSync(source, 'utf8')

ARGV['hidden-paths'] = ARGV['hidden-paths'].split(',').map((s) -> s.trim())
ARGV['hidden-paths'] = _.reject(ARGV['hidden-paths'], (s) -> s == "")

# tracer

tracer = new Tracer ARGV.source,
  showFullPath: true,
  hiddenPaths: ARGV['hidden-paths']
  matchesNode: (node, options) ->
    if options.grep != "" and not node.path.includes(options.grep)
      false
    else if options.nodeType != "" and node.type != options.nodeType
      false
    else
      true

# Template

if ARGV["use-compiled"]
  try
    Template = require("./template")
  catch exception
    u.error("parser doesn't exist or is invalid\n")
    u.log(exception)
    process.exit(1)
else
  try
    Template = peg.generate(
      fs.readFileSync("#{ROOT}/template.pegjs", 'utf8')
      trace: true
    )
  catch exception
    u.error("parser can't be generated\n")
    u.error("#{exception.name}: #{exception.message}")
    process.exit(1)

# parsing

matchOptions = {
  grep: ARGV.grep || ""
  nodeType: ARGV['node-type'] || ""
}

try
  result = Template.parse(ARGV.source, tracer: tracer)
  u.log(tracer.getParseTreeString(matchOptions), colored: false) if ARGV.debug
  u.log(u.json(result))
catch exception
  throw exception unless exception.location

  u.log(tracer.getParseTreeString(matchOptions)) if ARGV.debug

  if exception.location.start.line
    u.log(ARGV.source.split("\n")[exception.location.start.line - 1], colored: false)
  else
    u.log(ARGV.source)

  start = exception.location.start
  end = exception.location.end

  u.error('^'.padStart(start.column, ' ').padEnd(end.column, '^')) if start
  u.error("#{exception.name}: at \"#{exception.found || ""}\" (#{exception.message})")

  process.exit(1)
