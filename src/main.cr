require "option_parser"
require "colorize"
require "./lib/Xlib"
require "wait_group"
require "file_utils"
ISO_BLOCKSIZE=2048
def check_iso(path : String)
    !File.exists?(path) && abort "Error:ISO Dose not exists!!".colorize.red,1
    !path.rindex(".iso") && abort "Error:This File not ISO!!".colorize.red,1
    Xlib.call do
        Xlib.iso=iso_open(path)
        cdio_list=iso_readdir(iso,"/")
        file_list=[] of String
        cdio_nodelist(cdio_list).skip(2).each do |node|
            is=cdio_list_node_data(node)
            dood=uninitialized UInt8
            istat=is.value
            iso_name_translate(is.value.filename.to_unsafe,pointerof(dood))
            file_list << (name=String.new(pointerof(dood)))
            Xlib.content.push({filename: name,type: istat.type,lsn: istat.lsn,bytesize: istat.total_size}
            ) if ([name] & ["install.img","TRANS.TBL","trans.tbl"]).empty?
        end
        cdio_list_free(cdio_list,1,nil)
        if ((file_list & ["kernel","initrd.img"]) | (file_list & ["system.efs","system.sfs"])).empty?
            abort("Error:This ISO file is not suitable".colorize.red,1)
            iso_close(iso)
        end
        puts "ISO is ok!".colorize.green
        ["/efi/boot","/boot/grub"].each do |addr|
            cdio_list=iso_readdir(iso,addr)
            cdio_nodelist(cdio_list).skip(2).each do |node|
                is=cdio_list_node_data(node)
                dood=uninitialized UInt8
                istat=is.value
                iso_name_translate(is.value.filename.to_unsafe,pointerof(dood))
                name=String.new(pointerof(dood))
                unless ([name] & ["grub.cfg","android.cfg"]).empty?
                    xdood=Bytes.new(0)
                    blocks=to_block(istat.total_size)
                    blocks.times do |i|
                        buf=Bytes.new(VC365::ISO_BLOCKSIZE)
                        iso_seek_read(iso,buf,istat.lsn + i,1)
                        xdood +=buf
                    end
                    Xlib.grub_cfg[name]=String.new(xdood).lines
                end
            end
            cdio_list_free(cdio_list,1,nil)
        end
        Xlib.grub_cfg.delete("grub.cfg") if Xlib.grub_cfg.has_key?("android.cfg")
        iso_close(iso)
        Xlib.iso_path=path
    end
end
def installation_folder
    unless Xlib.idir?
        loop do
            puts "Enter installation folder".colorize.green.dim
            print "> "
            folder=gets
            if Dir.exists?(folder)
                Xlib.idir=Path[folder.rchop('/')].expand(home: true)
                break
            end if folder
            print "Folder dose not exists!\n".colorize.red.dim
        end
    else
        abort("Error:Please select iso".colorize.red,1) unless Xlib.iso?
        abort("Error:Folder dose not exists!".colorize.red,1) unless Dir.exists?(Xlib.idir)
    end
    dood=uninitialized VC365::StatFs
    Xlib.data_img=Xlib::DataImg.new(dood.f_type.to_s(16)=="4d44" ? 1
    : 2) if Xlib.statfs(Xlib.idir.to_s, pointerof(dood)).zero?
    unless Dir.children(Xlib.idir).size < 2
        name="Android-x86"
        puts "Enter installation folder name(optional)".colorize.green.dim
        print "(#NO for Skip)> "
	unless (name=gets)=="#NO"
        Xlib.idir=Xlib.idir.join(name.presence || "Android-x86")
        Dir.mkdir_p(Xlib.idir)
	end
    end
    Process.run("df",["--output=source",Xlib.idir.to_s]) do |processX|
        part=processX.output.gets_to_end.lines[1].strip
        if line=`ls -l /dev/disk/by-uuid`.lines.find { |i| i.ends_with?(part.lchop("/dev"))}
            Xlib.uuid=line.split[-3]
        else
            STDERR.puts "Error:Can not get UUID(#{part}) for grub.".colorize.red
        end
    end
    Process.run("df",["--output=target",Xlib.idir.to_s]) do |process|
        Xlib.mountpoint=process.output.gets_to_end.lines[1].strip
    end
end
def grub_config_generator
    if cfg=Xlib.grub_cfg.first_value
        kp=cfg.find! { |i| i.strip.starts_with?("linux")}.strip.split
	kp.shift(2)
        kp.reject! {|i| i.includes?('$') || i.includes?("DATA")}
        cfg=Xlib.grub_cfg[Xlib.grub_cfg.key_for(cfg)]=["set timeout=0",
        "search --fs-uuid #{Xlib.uuid rescue STDERR.puts "ERROR: Can not set UUID!".colorize.red} --set=root",
        "menuentry \"#{Xlib.idir.stem}\" {","\tset vc=/#{Xlib.idir.to_s.sub(Xlib.mountpoint,"").lchop('/')}",
        "\tlinux $vc/kernel #{(Xlib.grub_cfg["kp"]=kp).join(" ")} quiet","\tinitrd $vc/initrd.img","}"]
    else
        STDERR.puts "Error:Can not make grub.cfg.".colorize.red
    end
end
def start_install
    cfg=Xlib.grub_cfg.first_value
    File.write(Xlib.idir / "grub.cfg",cfg.join("\n")) if cfg
#    #WaitGroup.wait do |wg|
#        Xlib.content.each do |file|
#            #wg.spawn {
#            Xlib.call do
#                if file[:type].file?
#                    blocks = to_block(file[:bytesize])
#                    chunks=(blocks // 200) + 1
#                    dood=Array.new(chunks,Bytes.new(0))
#                    wgc=WaitGroup.new(chunks.to_i)
#                    counter=Channel(Int32).new(1)
#                    chunks.times do |i|
#                        Fiber::ExecutionContext::Isolated.new(i.to_s) do
#                            Xlib.call do
#                                cs=(i+1)==chunks ? blocks % 200 : 200
#                                cs.times do |ix|
#                                    ix=ix + i*200
#                                    buf = Bytes.new(VC365::ISO_BLOCKSIZE)
#                                    iso_seek_read(iso,buf,file[:lsn] + ix,1)
#                                    dood[i] +=buf
#                                    counter.send(1)
#                                    print "\rRead blocks(#{counter}->#{counter.receive})\t\t".colorize.dim
#                                end
#                            end
#                        ensure
#                            wgc.done
#                        end
#                    end
#                    wgc.wait
#                    xdood=Bytes.new(0)
#                    puts "SUM Bytes!!!"
#                    dood.each {|x| xdood+=x}
#                    dood.clear
#                    puts "\rExtracting #{file[:filename]}\t\t\t".colorize.cyan
#                    File.new(idir / file[:filename],"w").write(xdood)
#                end
#            end
#            #}
#        end
#    #end
    puts "\rExtracting ISO".colorize.cyan
    `bsdtar -xf #{Xlib.iso_path} -C #{Xlib.idir} &>/dev/null`
    Dir.children(Xlib.idir).each do |i|
        unless Xlib.content.find {|d| d[:filename]==i && d[:type].file?} || i=="grub.cfg"
            FileUtils.rm_rf(Xlib.idir / i)
        end
    end
    loop do
        puts %q(The installer is going to create a disk image to save the user data.
            Are you sure to create the image?).colorize.light_blue
	print "(y,n)> "
        inp = gets.try(&.strip)
        unless ([inp] & ["y","n"]).empty?
            if inp=="y"
                loop do
                    isf=Xlib.data_img.fat32? ? "(Limit 4000M)" : ""
                    puts "Please input the size of the data.img #{isf}".colorize.yellow
                    puts "(number->MByte | number#{"MB".colorize.underline}->MByte | number#{"GB".colorize.underline}->GByte)"
                    print "> "
                    value=gets.try(&.strip)
                    if value.ends_with?(/MB|GB|[0-9]/) && value.starts_with?(/[0-9]/)
                        dood=value.to_i? ? "#{value}M" : value
                        Process.run("mkfs.ext4",["-F","-b 4096","-L /data","#{Xlib.idir/"data.img"}",dood])
                        break
                    end if value
                    STDERR.puts "ERROR: #{value} is not a valid option.".colorize.red
                end
            else
                Dir.mkdir_p(Xlib.idir / "data")
            end
            break
        else
            STDERR.puts "ERROR: #{inp} is not a valid option.".colorize.red
        end
    end
    loop do
        puts %q(Do you want to install /system directory as read-write?
            Making /system be read-write is easier for debugging, 
            but it needs more disk space and longer installation time.).colorize.yellow.dim
	    print "(y,n)> "
        inp = gets.try(&.strip)
        unless ([inp] & ["y","n"]).empty?
            if inp=="y"
                begin
                    fname=Xlib.content[Xlib.content.index! {|f| f[:filename].includes?("system")}][:filename]
                    puts "Mounting #{fname}".colorize.cyan.dim
                    `sudo mkdir /mnt/sfs`
                    `sudo mkdir /mnt/system`
                    `sudo mount -o loop #{Xlib.idir}/#{fname} /mnt/sfs`
                    `sudo mount -o loop /mnt/sfs/system.img /mnt/system`
                    puts "Copying system.img".colorize.cyan
                    #FileUtils.cp_r("/mnt/system",Xlib.idir / "system")
                    `sudo cp -r /mnt/system #{Xlib.idir / "system"}`
                rescue ex
                    STDERR.puts "Error:Can not extract system.please check /mnt for cleanup\n#{ex}".colorize.red
                ensure
                    puts "Umounting system".colorize.red.dim
                    `sudo umount /mnt/system`
                    `sudo umount /mnt/sfs`
                    `sudo rm -rf /mnt/sfs /mnt/system`
                    if Dir.empty?(Xlib.idir / "system")
                        Dir.delete(Xlib.idir / "system")
                    else
                        File.delete(Xlib.idir / fname) if fname
                    end
                end
            end
            break
        else
            STDERR.puts "ERROR: #{inp} is not a valid option.".colorize.red
        end
    end
    puts "installation successfully".colorize.green.dim
    grub_entry=["#!/bin/sh","exec tail -n +3 $0","search --fs-uuid #{Xlib.uuid} --set=dood",
        "menuentry \"#{Xlib.idir.stem}\" --class android --class os {","\tconfigfile $dood/grub.cfg","}"
    ].join("\n")
    loop do
        puts %q(Do you want to install a GRUB boot entry?).colorize.light_cyan
	    print "(y,n)> "
        inp = gets.try(&.strip)
        unless ([inp] & ["y","n"]).empty?
            if inp=="y"
                loop do
                    puts %q(Enter GRUB entry priority).colorize.light_cyan
                	print "(default 35)> "
                    inpX = gets.try(&.strip.to_i?) || 35
                    `echo "#{grub_entry}" | sudo tee "/etc/grub.d/#{inpX}_#{Xlib.idir.stem}" >/dev/null`
                    if exe = Process.find_executable("update-grub")
                        `sudo #{exe}`
                    elsif exe = Process.find_executable("grub2-mkconfig")
                        `sudo #{exe} -o /boot/grub2/grub.cfg`
                    elsif exe = Process.find_executable("grub-mkconfig")
                        `sudo #{exe} -o /boot/grub/grub.cfg`
                    else
                         STDERR.puts "No GRUB configuration tool found.".colorize.red
                    end
                    break
                end
            else
                puts " GRUB ENTRY ".center(20,'#')
                puts grub_entry
            end
            break
        else
            puts "ERROR: #{inp} is not a valid option.".colorize.red
        end
    end
    puts "Done!".colorize.green
end
def info
    puts " Information ".center(25,'#')
    print "Kernel version: "
    puts `strings #{Xlib.idir}/kernel | grep "version"`.split[0].colorize.dim
    print "Kernel parametrs: ".colorize.light_gray
    puts "#{Xlib.grub_cfg["kp"].join(" ")} quiet".colorize.dark_gray
    if Dir.exists?(Xlib.idir / "system")
        props = Hash(String, String).new
        File.each_line(Xlib.idir / "system/build.prop") do |line|
            line = line.strip
            next if line.starts_with?('#') || line.empty?
            key, value = line.split('=', 2)
            props[key] = value if value
        end
        print "Android Version: ".colorize.blue
        puts "(#{props["ro.product.device"]}) #{props["ro.build.version.release"]}".colorize.light_blue
        print "ABI Supported: ".colorize.cyan.dim
        puts props["ro.product.cpu.abilist"].colorize.cyan
        if gl = props["ro.opengles.version"]?
            gl = gl.to_i
            major = gl >> 16
            minor = gl & 0xffff
            print "OpenGL ES: ".colorize.green.dim
            puts "#{major}.#{minor}".colorize.green
        end
    end
end
OptionParser.parse do |arg|
    arg.banner="Usage: vcdroid-installer [ISO Path | -i,--iso | -f,--folder | -h,--help | -v,--version]"
    arg.on("-i ISO", "--iso=ISO", "Set iso path.") do |iso|
        check_iso(iso)
    end
    arg.on("-f DIR", "--folder=DIR", "Set installation folder.") do |dir|
        Xlib.idir=Path[dir]
    end
    arg.on("-h", "--help", "Show this help.") {puts arg;exit}
    arg.on("-v", "--version", "Print the VCDroidInstaller version.") {puts "VCDroidInstaller v0.1.0";exit}

    arg.invalid_option do |flag|
        STDERR.puts "ERROR: #{flag} is not a valid option."
        STDERR.puts arg
        exit(1)
    end
    if ARGV.empty?
        STDERR.puts arg
        exit(1)
    elsif !ARGV[0].starts_with?('-')
        check_iso(ARGV[0]) unless Xlib.iso?
    end
end
installation_folder
grub_config_generator
puts "Start installation".colorize.magenta.bold
start_install
info