using MAT

include("SpikeGLX.jl")

"Read variables in `MATLAB` MAT file"
function readmat(f::AbstractString,vars...;optvars=["spike","lfp","digital","analog1k","image"])
    if isempty(vars)
        d=matread(f)
    else
        d=Dict()
        matopen(f) do file
            fvs = names(file)
            reqvars=setdiff(fvs,optvars)
            ovs = intersect(optvars,vars)
            for i in setdiff(ovs,fvs)
                @warn """Optional variable "$i" not found in "$f"."""
            end
            vs=union(reqvars,intersect(fvs,ovs))
            if !isempty(vs)
                for v in vs
                    d[v]=read(file,v)
                end
            end
        end
    end
    return d
end

"Read `DataExport` Metadata MAT File"
function readmeta(f::AbstractString)
    d = readmat(f)["Tests"]
    mat2julia!(d)
    DataFrame(d)
end

"Convert `MATLAB` type to `Julia` type with proper dimention"
function mat2julia!(x;isscaler = true,isvector = true)
    if x isa Dict
        for k in keys(x)
            x[k]=mat2julia!(x[k],isscaler=isscaler,isvector=isvector)
        end
    elseif x isa Array
        if ndims(x)==2
            nr,nc = size(x)
            if nr==1 && nc==1
                x = isscaler ? x[1,1] : isvector ? dropdims(x,dims=2) : x
            elseif nr==1 && nc>1
                x = isvector ? dropdims(x,dims=1) : x
            elseif nr>1 && nc==1
                x = isvector ? dropdims(x,dims=2) : x
            end
        end
        if x isa Array{Any} || x isa Array{Array} || x isa Array{Dict}
            for i in 1:length(x)
                x[i]=mat2julia!(x[i],isscaler=isscaler,isvector=isvector)
            end
        elseif x isa Dict
            for k in keys(x)
                x[k]=mat2julia!(x[k],isscaler=isscaler,isvector=isvector)
            end
        end
    end
    return x
end

"Load images in directory"
function loadimageset(dir;name=[],n=typemax(Int),alpha=false)
    isdir(dir) || error("Invalid Directory")
    for (root, dirs, files) in walkdir(dir)
        if isempty(name)
            n = min(n,length(files))
            n<=0 && error("n <= 0")
            imgs=load.(joinpath.([root],string.(1:n).*splitext(files[1])[2]))
        else
            imgs=load.(joinpath.([root],string.(Int.(name)).*splitext(files[1])[2]))
        end
        if alpha
            imgs = map(i->coloralpha.(i),imgs)
        end
        return imgs
    end
end

"Default digital input channels"
const CondDCh=1
const MarkDCh=2
const StartDCh=3
const StopDCh=4
const Bits16DCh=5
"Get digital channel time and value."
function digitaldata(dataset::Dict,ch)
    chidx = findfirst(dataset["digital"]["channel"].==ch)
    if !isempty(chidx)
        return dataset["digital"]["time"][chidx],dataset["digital"]["data"][chidx]
    else
        return [],[]
    end
end
"Parse bit event time and value."
function digitalbit(dt,dv,bits...)
    n = length(dt)
    maxbit = maximum(bits)
    bn = length(bits)
    bt = [zeros(Float64,n+1) for _ in 1:bn]
    bv = [zeros(UInt8,n+1) for _ in 1:bn]
    j=ones(Int,bn)
    for i in 1:n
        ds = digits(UInt8,dv[i],2,maxbit)
        for b in 1:bn
            v=ds[bits[b]]
            if v != bv[b][j[b]]
                j[b]=j[b]+1
                bt[b][j[b]]=dt[i]
                bv[b][j[b]]=v
            end
        end
    end
    for b in 1:bn
        bt[b]=bt[b][2:j[b]]
        bv[b]=bv[b][2:j[b]]
    end
    if bn==1
        return bt[1],bv[1]
    end
    return bt,bv
end

"Prepare Dataset in `MATLAB` MAT File"
prepare(f::AbstractString,vars...)=prepare!(readmat(f,vars...),true)
function prepare!(d::Dict,ismat=true)
    ismat && mat2julia!(d)
    if haskey(d,"secondperunit")
        settimeunit(d["secondperunit"])
    end
    if haskey(d,"sourceformat")
        sf = d["sourceformat"]
        if sf=="Ripple"
            d=prepare_ripple!(d)
        elseif sf=="OI"
            d=prepare_oi!(d)
        elseif sf=="Experica"
            d=prepare_experica!(d)
        end
    end
    if !haskey(d,"spike")
        if haskey(d,"spike_kilosort")
            d["spike"] = unitfyspike_kilosort(d["spike_kilosort"])
        end
    end
    return d
end
"Prepare `Ripple` Data"
function prepare_ripple!(d::Dict)
    if haskey(d,"spike")
        st=d["spike"]["time"]
        su=d["spike"]["unitid"]
        for i in 1:length(st)
            if ndims(st[i])==0
                st[i]=[st[i]]
                su[i]=[su[i]]
            end
        end
    end
    return d
end
"Prepare `Optical Imaging` Block Data"
function prepare_oi!(d::Dict)
    return d
end
"Prepare `Experica` Experiment Data"
function prepare_experica!(d::Dict)
    return d
end

"Extract state time of condtest"
function statetime(ct::Dict;statetype::AbstractString="CONDSTATE",state::AbstractString="COND")
    if haskey(ct,statetype)
        filter!(l->!isempty(l),map(i->begin
        t = filter!(k->!isempty(k),map(j->haskey(j,state) ? j[state] : [],i))
        length(t)==1 ? t[1] : t
    end,ct[statetype]))
else
    []
end
end

function getparam(d::Dict,name,fromobject="")
    for k in keys(d)
        startswith(k,name) && endswith(k,fromobject) && return d[k]
    end
end

"Get `CondTestCond` DataFrame"
function condtestcond(ctcd::Dict)
    ctc = DataFrame(ctcd)
    return ctc
end
"Get `CondTest` DataFrame"
function condtest(ctd::Dict)
    ct = DataFrame(ctd)
    return ct
end
"Get `CondTest` and `CondTestCond` DataFrame"
function ctctc(ctd::Dict,ctcd::Dict)
    ct = condtest(ctd)
    ctc = condtestcond(ctcd)
    return ct,ctc
end
function ctctc(ex::Dict)
    return ctctc(ex["CondTest"],ex["CondTestCond"])
end

"Map time to data timeline, optionally add latency."
function maptodatatime(x,ex::Dict;addlatency=true)
    t=x*(1+ex["TimerDriftSpeed"])+ex["t0"]
    if addlatency
        t+=ex["Latency"]
    end
    return t
end

function subrm(rm,fs,epochs;chs=1:size(rm,1),meta=[],bandpass=[1,100])
    f = nothing
    if !isempty(meta)
        f = x -> gaincorrectim(x,meta)
        if !isempty(bandpass)
            f = x -> hlpass(rmline!(gaincorrectim(x,meta),fs),fs,high=bandpass[1],low=bandpass[2])
        end
    end
    subrm(rm,fs,epochs,chs,fun=f)
end

"Organize each spiking unit info from `Kilosort` result"
function unitfyspike_kilosort(data::Dict;templateradius=120)
    # spike sorting result
    spiketime = data["time"]
    spiketemplate = data["template"]
    spikecluster = data["cluster"]
    spikeamplitude = data["amplitude"]

    templates = data["clustertemplates"] # nTemplates x nTimePoints x nChannels
    chmap = data["chanmap"]
    chposition = data["channelposition"]
    winv = data["whiteningmatrixinv"]

    templatesunwhiten = zeros(size(templates))
    for t in 1:size(templates,1)
        templatesunwhiten[t,:,:] = templates[t,:,:]*winv
    end
    templatesunwhiten_height = dropdims(map(i->-(-(i...)),extrema(templatesunwhiten,dims=2)),dims=2) # unwhiten template height between trough to peak, nTemplates x nChannels
    templatesunwhiten_maxheight_chposition = map(i->chposition[Tuple(i)[2],:],argmax(templatesunwhiten_height,dims=2))
    templatemask = [norm(chposition[j,:].-templatesunwhiten_maxheight_chposition[i]) > templateradius for i in 1:size(templatesunwhiten_height,1), j in 1:size(chposition,1)]
    templatesunwhiten_height[templatemask].=0.0

    # each unit
    unitid = data["clusterid"]
    unitgood = data["clustergood"].==1
    unitindex = [spikecluster.==i for i in unitid]
    unitspike = map(i->spiketime[i],unitindex)
    unitamplitude = map(i->spikeamplitude[i],unitindex)
    unittemplate = map(i->spiketemplate[i],unitindex)
#    unittemplatesunwhiten = map(i->templatesunwhiten[i,:,:],1:size(templatesunwhiten,1))
    unittemplatesunwhiten_height = map(i->templatesunwhiten_height[i,:],1:size(templatesunwhiten,1))

    unitposition = vcat(map(w->sum(w.*chposition,dims=1)/sum(w),unittemplatesunwhiten_height)...) # center of mass from all weighted unit template channel positions

    return Dict("unitid"=>unitid,"unitgood"=>unitgood,"unitspike"=>unitspike,"chposition"=>chposition,"unitposition"=>unitposition)
end


"convert `Matlab` struct of array to `DataFrame`"
matdictarray2df(d) = DataFrame(Any[squeeze(v,2) for v in values(d)],[Symbol(k) for k in keys(d)])

"Regular expression to match `VLab` data file names"
function vlabregex(testtype;subject="[0-9]",maxch=1,cell="[a-z]",maxrepeat=3,format="mat")
    mr = lpad(maxrepeat,2,0)
    Regex("^$subject+[A-Za-z]+[1-$maxch]$cell$testtype[0-$(mr[1])][0-$(mr[2])]\\.$format")
end

"Get matched file names in path"
function getdatafile(testtype;subject="[0-9]",path="./data")
    matchfile(vlabregex(testtype,subject=subject),path=path)
end

"Regular Expression to match Optical Imaging `VDAQ` block file name"
function oifileregex(;subject="[A-Za-z0-9]",session="[A-Za-z0-9]",experimentid="[0-9]",format="mat")
    Regex("^$subject+_$session*_?E$experimentid+B[0-9]+[.]$format")
end

"Get Optical Imaging `VDAQ` matched files in directory"
function getoifile(;subject="[A-Za-z0-9]",session="[A-Za-z0-9]",experimentid="[0-9]",format="mat",dir="",adddir=false)
    matchfile(oifileregex(subject=subject,session=session,experimentid=experimentid,format=format),dir=dir,adddir=adddir)
end

"Regular Expression to match `Experica` data file name"
function expericafileregex(;subject="[A-Za-z0-9]",session="[A-Za-z0-9]",site="[A-Za-z0-9]",test="[A-Za-z0-9]",maxrepeat=10,format="mat")
    mr = lpad(maxrepeat,2,"0");d2=mr[1];d1=parse(Int,d2)>0 ? 9 : mr[2]
    Regex("^$subject+_$session*_?$site*_?$test+_[0-$d2]?[0-$d1][.]$format")
end

"Get matched `Experica` files in directory"
function getexpericafile(;subject="[A-Za-z0-9]",session="[A-Za-z0-9]",site="[A-Za-z0-9]",test="[A-Za-z0-9]",maxrepeat=10,format="mat",dir="",adddir=false)
    matchfile(expericafileregex(subject=subject,session=session,site=site,test=test,maxrepeat=maxrepeat,format=format),dir=dir,adddir=adddir)
end

"Get matched files in directory, optionally add directory to get file path"
function matchfile(pattern::Regex;dir="",adddir::Bool=false)
    fs = filter!(f->occursin(pattern,f),readdir(dir))
    if adddir
        fs=joinpath.(dir,fs)
    end
    return fs
end
