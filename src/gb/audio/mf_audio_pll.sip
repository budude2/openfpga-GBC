set_global_assignment -entity "mf_audio_pll" -library "lib_mf_audio_pll" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "mf_audio_pll" -library "lib_mf_audio_pll" -name IP_TOOL_VERSION "23.1"
set_global_assignment -entity "mf_audio_pll" -library "lib_mf_audio_pll" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_mf_audio_pll" -name SPD_FILE [file join $::quartus(sip_path) "mf_audio_pll.spd"]

set_global_assignment -library "lib_mf_audio_pll" -name MISC_FILE [file join $::quartus(sip_path) "mf_audio_pll_sim/mf_audio_pll.vo"]
