module TeensyLoaderCLI

using teensy_loader_cli_jll
using Downloads
using Logging

struct MCU
    id::Symbol    
end

const at90usb162      = MCU(:at90usb162)
const atmega32u4      = MCU(:atmega32u4)
const at90usb646      = MCU(:at90usb646)
const at90usb1286     = MCU(:at90usb1286)
const mkl26z64        = MCU(:mkl26z64)
const mk20dx128       = MCU(:mk20dx128)
const mk20dx256       = MCU(:mk20dx256)
const mk66fx1m0       = MCU(:mk66fx1m0)
const mk64fx512       = MCU(:mk64fx512)
const imxrt1062       = MCU(:imxrt1062)
const TEENSY2         = MCU(:TEENSY2)
const TEENSY2PP       = MCU(:TEENSY2PP)
const TEENSYLC        = MCU(:TEENSYLC)
const TEENSY30        = MCU(:TEENSY30)
const TEENSY31        = MCU(:TEENSY31)
const TEENSY32        = MCU(:TEENSY32)
const TEENSY35        = MCU(:TEENSY35)
const TEENSY36        = MCU(:TEENSY36)
const TEENSY40        = MCU(:TEENSY40)
const TEENSY41        = MCU(:TEENSY41)
const TEENSY_MICROMOD = MCU(:TEENSY_MICROMOD)

"""
    has_soft_reboot(::MCU)

Whether or not the given MCU supports soft reboot functionality through TeensyLoaderCLI.    
"""
function has_soft_reboot(mcu::MCU)
    mcu.id in (:TEENSY31,
               :TEENSY32,
               :TEENSY35,
               :TEENSY36,
               :TEENSY40,
               :TEENSY41)
end

"""
    install_udev(;dry=true)

Installs the udev rules for Teensy boards. 

The rules are downloaded from [https://www.pjrc.com/teensy/00-teensy.rules](https://www.pjrc.com/teensy/00-teensy.rules).
The download has a timeout of 5 minutes.

Keyword arguments:
 * `dry`: Whether to do a dry run. When set to `true`, no actions other than downloading are taken. Set to `false` to change your system.

`install_udev` will abort if the target file already exists. Check that the existing udev rule is correct for your
devices and either use the existing rules, or remove the file to try again.

!!! warn "sudo"
    The rules are installed system wide, into `/etc/udev/rules.d/00-teensy.rules`. This requires `sudo`
    permissions, which is why this needs to be done manually. In addition, this requires `udevadm`.
"""
function install_udev(;dry=true)
    installpath = "/etc/udev/rules.d/00-teensy.rules"
    if ispath(installpath)
        @warn "udev rule file already exists - aborting."
        return
    end

    dry && @info "Doing a dry run - no changes will occur."
    !dry && (@warn "Doing a live run - your system will be affected."; sleep(5))
    println()
    
    mktemp() do dlpath, dlio
        @info "Downloading udev rules to `$dlpath`"
        Downloads.download("https://www.pjrc.com/teensy/00-teensy.rules", dlio; timeout=5*60.0)
        @info "Installing rules file to `/etc/udev/rules.d/00-teensy.rules`"
        mvcmd = `sudo install -o root -g root -m 0664 $dlpath $installpath`
        @info "Installing rules" Cmd=mvcmd
        !dry && run(mvcmd)

        udevadmctl = `sudo udevadm control --reload-rules`
        @info "Reloading rules" Cmd=udevadmctl
        !dry && run(udevadmctl)

        udevadmtgr = `sudo udevadm trigger`
        @info "Triggering udev events" Cmd=udevadmtgr
        !dry && run(udevadmtgr)
    end
    @info "Done!"
    nothing
end

"""
    help_cmd()

Print out the `--help` section provided by the `teensy_loader_cli` binary.
The printed flags can only be used when using the `teensy_loader_cli` binary directly.

See also: [help](@ref), [program!](@ref)
"""
function help_cmd()
    err = Pipe()
    proc = teensy_loader_cli() do b
        run(pipeline(`$b --help`; stderr=err); wait=false)
    end
    # this thing complains with a bad exit code when it doesn't get what it cares about..
    wait(proc)
    write(stdout, readavailable(err))
    nothing
end

"""
    boot!(;wait=true, verbose=false)

Boot the attached Teensy device, but do not upload a new program.

Keyword arguments:

 * `wait = true`
    * Wait until a device is found.
 * `verbose = false`
    * Give more verbose output.
"""
function boot!(;wait=true, verbose=false)
    w = wait ? `-w` : ``
    v = verbose ? `-v` : ``
    proc = teensy_loader_cli() do b
        run(`$b -b $w $v`; wait=false)
    end
    success(proc)
    nothing
end

"""
    list_mcus()

List the microcontrollers supported by TeensyLoaderCLI.

!!! note "Programming"
    The names given by the `teensy_loader_cli` binary can be used to
    program the Teensy in `program!`. They are available via `TeensyLoaderCLI.<mcu>`,
    where `<mcu>` is one of the MCUs given by this function.
"""
function list_mcus()
    out = Pipe()
    proc = teensy_loader_cli() do b
        run(pipeline(`$b --list-mcus`; stdout=out); wait=false)
    end
    wait(proc)
    write(stdout, readavailable(out))
    nothing
end

"""
    program!(mcu::MCU, file::String;
                wait       = true
                verbose    = false
                hardreboot = false
                softreboot = false
                noreboot   = false)

Upload the program located at `file` to the connected teensy device. `file` must be in `ihex` format.

Positional Arguments:

 * `mcu`
    * One of the supported MCU targets listed in `list_mcus()`.
 * `file`
    * The binary file to be uploaded to the device. Must be in `ihex` format.

Keyword Arguments:

 * `wait = true`
    * Wait until a device is detected.
 * `verbose = false`
    * Give more verbose output.
 * `hardreboot = false`
    * Use a hard reboot is the device is not online.
 * `softreboot = false`
    * Use a soft reboot if the devise is not online.
    * Only available for Teensy 3.x & 4.x.
 * `noreboot = false`
    * Don't reboot the Teensy after programming.
"""
function program!(mcu::MCU, file::String; wait=true, verbose=false, hard=false, soft=false, noreboot=false)
    w = wait ? `-w` : ``
    v = verbose ? `-v` : ``
    h = hard ? `-r` : ``
    s = soft ? `-s` : ``
    n = noreboot ? `-n` : ``

    if h && s
        @error "Can only specify either hard or soft reboot!"
        return
    end

    if s && !has_soft_reboot(mcu)
        @error "Only Teensy 3.x & 4.x support soft reboot!"
        return
    end

    if n && !(h || s)
        @error "Cannot specify both to reboot and not to reboot!"
        return
    end
    
    if !ispath(file)
        @error "Given path is not a file!" Path=file
        return
    end

    verbose && @info "Uploading program at `$file`"
    proc = teensy_loader_cli() do b
        run(`$b --mcu=$(mcu.id) $w $v $h $s $n $file`; wait=false)
    end
    success(proc)
    nothing
end

end # module TeensyLoaderCLI
