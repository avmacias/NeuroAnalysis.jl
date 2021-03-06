function alphablend(src,dst,srcfactor,dstfactor=1-srcfactor)
    srcfactor.*src+dstfactor.*dst
end
function alphablend(src::Colorant,dst::Colorant)
    srcfactor = alpha(src)
    srcfactor.*src+(1-srcfactor).*dst
end
function alphamask(src;radius=0.5,sigma=0.15,masktype="Disk")
    if masktype=="Disk"
        alphamask_disk(src,radius)
    elseif masktype=="Gaussian"
        alphamask_gaussian(src,sigma)
    elseif masktype=="DiskFade"
        alphamask_diskfade(src,radius,sigma)
    else
        return copy(src),Int[]
    end
end
function alphamask_disk(src,radius)
    dims = size(src);dim1=dims[1];dim2=dims[2];mindim=min(dim1,dim2)
    hh = dim1/2;hw = dim2/2;dst = copy(src);unmaskidx=Int[];li = LinearIndices(dims)
    for i=1:dim1,j=1:dim2
        d = sqrt((i-hh)^2+(j-hw)^2)-radius*mindim
        if d>0
            dst[i,j]=coloralpha(color(dst[i,j]),0)
        else
            push!(unmaskidx,li[i,j])
        end
    end
    return dst,unmaskidx
end
function alphamask_gaussian(src,sigma)
    dims = size(src);dim1=dims[1];dim2=dims[2];mindim=min(dim1,dim2)
    hh = dim1/2;hw = dim2/2;dst = copy(src);unmaskidx=Int[];li = LinearIndices(dims)
    for i=1:dim1,j=1:dim2
        d = ((i-hh)^2+(j-hw)^2)/(0.5*mindim)^2
        dst[i,j]=coloralpha(color(dst[i,j]),alpha(dst[i,j])*exp(-d/(2*sigma^2)))
        push!(unmaskidx,li[i,j])
    end
    return dst,unmaskidx
end
function alphamask_diskfade(src,radius,sigma)
    dims = size(src);dim1=dims[1];dim2=dims[2];mindim=min(dim1,dim2)
    hh = dim1/2;hw = dim2/2;dst = copy(src);unmaskidx=Int[];li = LinearIndices(dims)
    for i=1:dim1,j=1:dim2
        d = sqrt((i-hh)^2+(j-hw)^2)/mindim-radius
        if d>0
            dst[i,j] = coloralpha(color(dst[i,j]),alpha(dst[i,j])*erfc(sigma*d))
        else
            push!(unmaskidx,li[i,j])
        end
    end
    return dst,unmaskidx
end

function clampscale(x,min::Real,max::Real)
    scaleminmax(min,max).(x)
end
clampscale(x) = clampscale(x,extrema(x)...)
function clampscale(x,sdfactor)
    m=mean(x);sd=std(x)
    clampscale(x,m-sdfactor*sd,m+sdfactor*sd)
end
function oiframeresponse(frames;frameindex=nothing,baseframeindex=nothing)
    if frameindex==nothing
        r = dropdims(sum(frames,dims=3),dims=3)
    else
        r = dropdims(sum(frames[:,:,frameindex],dims=3),dims=3)
    end
    if baseframeindex!=nothing
        r./=dropdims(sum(frames[:,:,baseframeindex],dims=3),dims=3)
        r.-=1
    end
    return r
end
function oiresponse(response,stimuli;ustimuli=sort(unique(stimuli)),blankstimuli=0,
    stimuligroup=Any[1:length(findall(ustimuli.!=blankstimuli))],filter=nothing,sdfactor=nothing)
    if filter==nothing
        if sdfactor==nothing
            rs = map(i->cat(response[stimuli.==i]...,dims=3),ustimuli)
        else
            rs = map(i->cat(clampscale.(response[stimuli.==i],sdfactor)...,dims=3),ustimuli)
        end
    else
        if sdfactor==nothing
            rs = map(i->cat(imfilter.(response[stimuli.==i],[filter])...,dims=3),ustimuli)
        else
            rs = map(i->cat(clampscale.(imfilter.(response[stimuli.==i],[filter]),sdfactor)...,dims=3),ustimuli)
        end
    end
    responsemean = map(i->dropdims(mean(i,dims=3),dims=3),rs)
    responsesd = map(i->dropdims(std(i,dims=3),dims=3),rs)
    responsen = map(i->size(i,3),rs)

    blank = responsemean[findfirst(ustimuli.==blankstimuli)]
    rindex = ustimuli.!=blankstimuli
    rmap=responsemean[rindex]
    cocktail=Any[];cocktailmap=Any[]
    for ig in stimuligroup
        c = dropdims(mean(cat(rmap[ig]...,dims=3),dims=3),dims=3)
        cm = map(i->i./c,rmap[ig])
        push!(cocktail,c)
        append!(cocktailmap,cm)
    end
    return blank,cocktail,DataFrame(stimuli=ustimuli[rindex],map=rmap,blankmap=map(i->i./blank,rmap),cocktailmap=cocktailmap),
    DataFrame(stimuli=ustimuli,map=responsemean,mapsd=responsesd,mapn=responsen)
end
function oicomplexmap(maps,angles;isangledegree=true,isangleinpi=true,presdfactor=3,filter=Kernel.DoG((3,3),(30,30)),sufsdfactor=3)
    if isangledegree
        angledegree = sort(angles)
        angles = deg2rad.(angles)
    else
        angledegree = sort(rad2deg.(angles))
    end
    if isangleinpi
        angles *=2
    end
    if presdfactor!=nothing
        maps=map(i->clampscale(i,presdfactor),maps)
    end
    if filter != nothing
        maps=map(i->imfilter(i,filter),maps)
    end
    if sufsdfactor!=nothing
        maps=map(i->clampscale(i,sufsdfactor),maps)
    end

    cmap=dropdims(sum(cat(map((m,a)->Complex(cos(a),sin(a)).*-m,maps,angles)...,dims=3),dims=3),dims=3)
    amap,mmap = angleabs(cmap)
    return Dict("complex"=>cmap,"angle"=>amap,"abs"=>mmap,"rad"=>sort(angles),"deg"=>angledegree)
end
function angleabs(cmap)
    amap = angle.(cmap);amap[amap.<0]=amap[amap.<0] .+ 2pi
    mmap = clampscale(abs.(cmap))
    return amap,mmap
end
anglemode(a,theta) = theta[findclosestangle(a,theta)]
findclosestangle(a,theta) = findmin(abs.(angle.(Complex(cos(a),sin(a))./Complex.(cos.(theta),sin.(theta)))))[2]

"Generate Grating"
function grating(;ori=0,sf=0.1,phase=0,tf=1,t=0,size=10,ppd=30)
    pc = floor(Int,size*ppd/2)
    psize = 2pc+1
    g = fill(0.5,psize,psize)
    isnan(ori) && return g
    sinv,cosv = sincos(ori)
    for i in 1:psize, j in 1:psize
        u = (j-pc)/pc/2
        v = (pc-i)/pc/2
        d = cosv * v * size - sinv * u * size
        g[i,j] = (sin(2π * (sf * d - tf * t + phase)) + 1) / 2
    end
    return g
end
