@[Link(ldflags:"`pkg-config -libs libiso9660`")]
@[Link("archive")]
lib VC365
    ISO_BLOCKSIZE=2048
    type ISO=Void*
    type CdioList=Void*
    type CdioNode=Void*
    enum Type
        File = 1
        Dir = 2
    end
    @[Packed]
    struct Iso9660Dtime
        dt_year   : UInt8
        dt_month  : UInt8
        dt_day    : UInt8
        dt_hour   : UInt8
        dt_minute : UInt8
        dt_second : UInt8
        dt_gmtoff : Int8
    end
    @[Packed]
    struct Iso9660Ltime
        lt_year    : UInt8[4]
        lt_month   : UInt8[2]
        lt_day     : UInt8[2]
        lt_hour    : UInt8[2]
        lt_minute  : UInt8[2]
        lt_second  : UInt8[2]
        lt_hsecond : UInt8[2]
        lt_gmtoff  : Int8
    end
    union RockTimeUnion
        ltime : Iso9660Ltime
        dtime : Iso9660Dtime
    end
    @[Packed]
    struct IsoRockTime
        b_used     : Bool
        b_longdate : Bool
        t : RockTimeUnion
    end
    enum Bool3Way
        Nope  = 0
        Yep   = 1
        Dunno = 2
    end
    @[Packed]
    struct IsoRockStatbuf
        b3_rock : Bool3Way         # bool_3way_t
        st_mode : UInt32           # posix_mode_t
        st_nlinks : UInt32         # posix_nlink_t
        st_uid : UInt32            # posix_uid_t
        st_gid : UInt32            # posix_gid_t
        s_rock_offset : UInt8
        i_symlink : Int32
        i_symlink_max : Int32
        psz_symlink : Pointer(UInt8)
        create : IsoRockTime
        modify : IsoRockTime
        access : IsoRockTime
        attributes : IsoRockTime
        backup : IsoRockTime
        expiration : IsoRockTime
        effective : IsoRockTime
        i_rdev : UInt32
        u_su_fields : UInt32
    end
    struct Tm
        tm_sec : Int32
        tm_min : Int32
        tm_hour : Int32
        tm_mday : Int32
        tm_mon : Int32
        tm_year : Int32
        tm_wday : Int32
        tm_yday : Int32
        tm_isdst : Int32
        tm_gmtoff : Int64
        tm_zone : UInt8*
    end
    @[Packed]
    struct Iso9660Xa
        group_id   : UInt16
        user_id    : UInt16
        attributes : UInt16
        signature  : UInt8[2]
        filenum    : UInt8
        reserved   : UInt8[5]
    end
    struct IsoStat
        rr : IsoRockStatbuf
        tm : Tm
        lsn : Int32
        size : UInt32
        secsize : UInt32
        total_size : UInt64
        xa : Iso9660Xa
        type : Type
        b_xa : Bool
        filename : UInt8[0]
    end
    struct StatFs
        f_type : Int64
        f_bsize : Int64
        dummy : UInt8[256]
    end

    fun iso_open=iso9660_open(path : UInt8*) : ISO
    fun iso_close=iso9660_close(iso : ISO)
    fun iso_readdir=iso9660_ifs_readdir(iso : ISO,psz_path : UInt8*) : CdioList
    fun cdio_list_begin=_cdio_list_begin(list : CdioList) : CdioNode
    fun cdio_list_free=_cdio_list_free(list : CdioList,free_data : Int32,free_fn : Void*) : Void
    fun cdio_list_node_next=_cdio_list_node_next(list : CdioNode) : CdioNode
    fun cdio_list_node_data=_cdio_list_node_data(node : CdioNode) : IsoStat*
    fun iso_name_translate=iso9660_name_translate(src : UInt8*, dest : UInt8*) : Void
    fun iso_seek_read=iso9660_iso_seek_read(iso : ISO, buffer : UInt8*,lsn : Int32,bytesize : Int64) : Int64

    fun statfs(dir : UInt8*,res : StatFs*) : Int32
end
module Xlib
    enum DataImg
        None;Fat32;NonLimit
    end
    alias Content ={filename: String,type: VC365::Type,lsn: Int32,bytesize: UInt64}
    class_property! iso : VC365::ISO
    class_property! iso_path : String
    class_property content =[] of Content
    class_property! idir : Path
    class_property data_img : DataImg=DataImg::None
    class_property! uuid : String
    class_property! mountpoint : String
    class_property grub_cfg =Hash(String,Array(String)).new
    def self.cdio_nodelist(list : VC365::CdioList)
        nodelist=[(node=VC365.cdio_list_begin(list))]
        until node.null?
            node=VC365.cdio_list_node_next(node)
            nodelist << node unless node.null?
        end
        nodelist
    end
    def self.to_block(bytes : Int)
        (bytes + VC365::ISO_BLOCKSIZE-1) // VC365::ISO_BLOCKSIZE
    end
    {% for m in VC365.methods %}
        def self.{{m.name}}(*args)
            VC365.{{m.name}}(*args)
        end
    {% end %}

    def self.call(&)
        with self yield
    end
end