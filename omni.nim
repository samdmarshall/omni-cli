# =======
# Imports
# =======

import os
import yaml
import osproc
import streams
import strutils

# =====
# Types
# =====

type SendCommand = object
  cmd: string
  arg: seq[string]
  
type OmniConfiguration = object
  send: SendCommand
  msgTemplate: string

# ===========================================
# this is the entry-point, there is no main()
# ===========================================

var config_data: OmniConfiguration

let kDefaultConfigPath = "~/.config/omni/config.yml"
let kOmniSyncServerMaildropAddressEnvVar = "OMNI_SYNC_MAILDROP_ADDR"
let kOmniCLIConfigEnvVar = "OMNI_CLI_CONFIG"

let default_prefs_path = os.expandTilde(kDefaultConfigPath)
let alternative_prefs_path = os.getEnv(kOmniCLIConfigEnvVar)

let use_alternative_config_path: bool = os.existsEnv(kOmniCLIConfigEnvVar) and alternative_prefs_path.len > 0

let load_prefs_path: string = 
  if use_alternative_config_path: alternative_prefs_path
  else: default_prefs_path

if not os.existsFile(load_prefs_path):
  echo("Unable to locate the config file, please create it at `" & kDefaultConfigPath & "` or define `" & kOmniCLIConfigEnvVar & "` in your environment")
  quit(QuitFailure)

let omni_sync_server_maildrop_address = os.getEnv(kOmniSyncServerMaildropAddressEnvVar)

if not os.existsEnv(kOmniSyncServerMaildropAddressEnvVar):
  echo("The environment variable `" & kOmniSyncServerMaildropAddressEnvVar & "` was not found, please define it as the name of the address (everything before `@sync.omnigroup.com`.")
  quit(QuitFailure)

let config_stream = streams.newFileStream(load_prefs_path)
yaml.serialization.load(config_stream, config_data)
config_stream.close()

write(stdout, "Create new todo: ")
let name = readLine(stdin)

write(stdout, "Additional Notes: ")
let body = readLine(stdin)

let maildrop_address = omni_sync_server_maildrop_address & "@sync.omnigroup.com"

let message_text = strutils.replace(config_data.msgTemplate, "{maildrop}", maildrop_address).replace("{name}", name).replace("{body}", body)

let sending_process = osproc.startProcess(config_data.send.cmd, "", config_data.send.arg)

let input_handle = osproc.inputHandle(sending_process)
let output_handle = osproc.outputHandle(sending_process)

var output_file: File
discard open(output_file, output_handle, fmRead)
    
var input_file: File
if open(input_file, input_handle, fmWrite):
  write(input_file, message_text)
  input_file.close()

let output = output_file.readAll().string
write(stdout, output)
