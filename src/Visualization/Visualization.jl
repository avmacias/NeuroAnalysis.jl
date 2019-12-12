using Plots,StatsPlots

export factorunit,huecolors,unitcolors,plotspiketrain,plotpsth,plotcondresponse,plotsta,plotanalog,plotunitposition,
plotcircuit

factorunit(fs::Vector{Symbol};timeunit=SecondPerUnit)=join(factorunit.(fs,timeunit=timeunit),", ")
function factorunit(f::Symbol;timeunit=SecondPerUnit)
    fu=String(f)
    if occursin("Ori",fu)
        fu="$fu (deg)"
    elseif fu=="dir"
        fu="Direction (deg)"
    elseif fu=="Diameter"
        fu="$fu (deg)"
    elseif fu=="SpatialFreq"
        fu="$fu (cycle/deg)"
    elseif fu=="TemporalFreq"
        fu = "$fu (cycle/sec)"
    elseif fu=="Time"
        if timeunit ==1
            fu="$fu (s)"
        elseif timeunit == 0.001
            fu="$fu (ms)"
        end
    elseif fu=="Response"
        fu="$fu (spike/s)"
    elseif fu=="ResponseF"
        fu="Response (% \\DeltaF / F)"
    end
    return fu
end

huecolors(n::Int;alpha=0.8,saturation=1,brightness=1)=[HSVA(((i-1)/n)*360,saturation,brightness,alpha) for i=1:n]

function unitcolors(uids=[];n=5,alpha=0.8,saturation=1,brightness=1)
    uc = huecolors(n,alpha=alpha,saturation=saturation,brightness=brightness)
    insert!(uc,1,HSVA(0,0,0,alpha))
    if !isempty(uids)
        uc=uc[sort(unique(uids)).+1]
    end
    return uc
end

function plotspiketrain(x,y;group::Vector=[],timeline=[0],colors=unitcolors(),title="",size=(800,550))
    nt = isempty(x) ? 0 : maximum(y)
    s = min(size[2]/nt,1)
    if isempty(group)
        scatter(x,y,label="SpikeTrain",markershape=:vline,size=size,markersize=s,markerstrokewidth = s,markerstrokecolor=RGBA(0.1,0.1,0.3,0.8),legend=false)
    else
        scatter(x,y,group=group,markershape=:vline,size=size,markersize=s,markerstrokewidth = s,markerstrokecolor=reshape(colors,1,:))
    end
    vline!(timeline,line=(:grey),label="TimeLine",grid=false,xaxis=(factorunit(:Time)),yaxis=("Trial"),title=(title),legend=false)
end
function plotspiketrain(sts::RVVector;uids::RVVector=RealVector[],sortvalues=[],timeline=[0],colors=unitcolors(),title="",size=(800,550))
    if isempty(uids)
        g=uids;uc=colors
    else
        fuids = flatrvv(uids,sortvalues)[1]
        g=map(i->"U$i",fuids);uc=colors[sort(unique(fuids)).+1]
    end
    plotspiketrain(flatrvv(sts,sortvalues)[1:2]...,group=g,timeline=timeline,colors=uc,title=title,size=size)
end

# function plotspiketrain1(x::Vector,y::Vector,c::Vector=[];xmin=minimum(x)-10,xmax=maximum(x)+10,xgroup::Vector=[],
#     ymin=minimum(y)-1,ymax=maximum(y)+1,timemark=[0],theme=Theme(),
#     colorkey="",colorfun=Scale.lab_gradient(colorant"white",colorant"red"),colorminv=[],colormaxv=[])
#     xl="Time (ms)";yl="Trial"
#     if isempty(c)
#         if isempty(xgroup)
#             plot(x=x,y=y,xintercept=timemark,theme,Geom.point,Geom.vline(color="gray",size=1pt),
#             Coord.Cartesian(xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax),Guide.xlabel(xl),Guide.ylabel(yl))
#         else
#             plot(x=x,y=y,xgroup=xgroup,xintercept=fill(timemark[1],length(x)),theme,
#             Geom.subplot_grid(Geom.point,Geom.vline(color="gray",size=1pt),free_x_axis=true),
#             Guide.xlabel(xl),Guide.ylabel(yl))
#         end
#     else
#         yl="$yl Sorted"
#         if isempty(colorminv);colorminv=minimum(c);end
#         if isempty(colormaxv);colormaxv=maximum(c);end
#         if isempty(xgroup)
#             plot(x=x,y=y,color=c,xintercept=timemark,theme,Geom.point,Geom.vline(color="gray",size=1pt),
#             Coord.Cartesian(xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax),Guide.xlabel(xl),Guide.ylabel(yl),Guide.colorkey(colorkey),
#             Scale.ContinuousColorScale(colorfun,minvalue=colorminv,maxvalue=colormaxv))
#         else
#             plot(x=x,y=y,color=c,xgroup=xgroup,xintercept=fill(timemark[1],length(x)),theme,
#             Geom.subplot_grid(Geom.point,Geom.vline(color="gray",size=1pt),free_x_axis=true),
#             Guide.xlabel(xl),Guide.ylabel(yl),Guide.colorkey(colorkey),
#             Scale.ContinuousColorScale(colorfun,minvalue=colorminv,maxvalue=colormaxv))
#         end
#     end
# end
# plotspiketrain1(rvs::RVVector;sortvar=[],xgroup::Vector=[],timemark=[0],theme=Theme(),colorkey="",colorfun=Scale.lab_gradient(colorant"white",colorant"red"),colorminv=[],colormaxv=[]) = plotspiketrain1(flatrvs(rvs,sortvar)...,xgroup=xgroup,timemark=timemark,theme=theme,colorkey=colorkey,colorfun=colorfun,colorminv=colorminv,colormaxv=colormaxv)


plotcondresponse(rs,ctc;factors=names(ctc),u=0,style=:path,title="",projection=[],linewidth=:auto,legend=:best,responseline=[])=plotcondresponse(Dict(u=>rs),ctc,factors,style=style,title=title,projection=projection,linewidth=linewidth,legend=legend,responseline=responseline)
function plotcondresponse(urs::Dict,ctc::DataFrame,factors;colors=unitcolors(collect(keys(urs))),style=:path,projection=[],title="",linewidth=:auto,legend=:best,responseline=[])
    mseuc = condresponse(urs,ctc,factors)
    plotcondresponse(mseuc,colors=colors,style=style,title=title,projection=projection,linewidth=linewidth,legend=legend,responseline=responseline)
end
function plotcondresponse(urs::Dict,cond::DataFrame;colors=unitcolors(collect(keys(urs))),style=:path,projection=[],title="",linewidth=:auto,legend=:best,responseline=[])
    mseuc = condresponse(urs,cond)
    plotcondresponse(mseuc,colors=colors,style=style,title=title,projection=projection,linewidth=linewidth,legend=legend,responseline=responseline)
end
function plotcondresponse(mseuc::DataFrame;colors=unitcolors(unique(mseuc[:u])),style=:path,projection=[],title="",linewidth=:auto,legend=:best,responseline=[],responsetype=:Response)
    us = sort(unique(mseuc[!,:u]))
    factors=setdiff(names(mseuc),[:m,:se,:u])
    nfactor=length(factors)
    if nfactor==1
        factor=factors[1]
        if typeof(mseuc[!,factor][1]) <: Array
            map!(string,mseuc[factor],mseuc[factor])
            style=:bar
        end
    elseif nfactor==2
        fm,fse,fa = factorresponse(mseuc)
        clim=maximum(skipmissing(fm))
        yfactor,xfactor = collect(keys(fa))
        y,x = collect(values(fa))
    else
        mseuc[:Condition]=condstring(mseuc[:,factors])
        factor=:Condition
        style=:bar
    end
    if nfactor==2
        x=float.(x)
        y=float.(y)
        heatmap(x,y,fm,color=:fire,title=title,legend=legend,xaxis=(factorunit(xfactor)),yaxis=(factorunit(yfactor)),colorbar_title=factorunit(responsetype),clims=(0,clim))
    else
        if projection==:polar
            c0 = mseuc[mseuc[!,factor].==0,:]
            c0[:,factor].=360
            mseuc = [mseuc;c0]
            mseuc[!,factor]=deg2rad.(mseuc[!,factor])
        end
        sort!(mseuc,factor)
        if projection==:polar
            p = @df mseuc Plots.plot(cols(factor),:m,yerror=:se,group=:u,line=style,markerstrokecolor=:auto,color=reshape(colors,1,:),label=reshape(["$(k.ug)$(k.u)" for k in eachrow(ugs)],1,:),
            grid=false,projection=projection,legend=legend,xaxis=(factorunit(factor)),yaxis=(factorunit(:Response)),title=(title),linewidth=linewidth)
        else
            p = @df mseuc plot(cols(factor),:m,yerror=:se,group=:u,line=style,markerstrokecolor=:auto,color=reshape(colors,1,:),label=reshape(["$(k.ug)$(k.u)" for k in eachrow(ugs)],1,:),
            grid=false,projection=projection,legend=legend,xaxis=(factorunit(factor)),yaxis=(factorunit(:Response)),title=(title),linewidth=linewidth)
        end
        if !isempty(responseline)
            for i in responseline
                hline!(p,[i[1]],ribbon=[i[2]],color=colors,legend=false)
            end
        end
        p
    end
end

plotpsth(rvv::RVVector,binedges::RealVector;timeline=[0],colors=[:auto],title="")=plotpsth(rvv,binedges,DataFrame(Factor="Value",i=[1:length(rvv)]),timeline=timeline,colors=colors,title=title)
function plotpsth(rvv::RVVector,binedges::RealVector,ctc::DataFrame,factor;timeline=[0],colors=nothing,title="")
    msexc = psth(rvv,binedges,ctc,factor)
    plotpsth(msexc,timeline=timeline,colors=colors==nothing ? huecolors(length(levels(msexc[:c]))) : colors,title=title)
end
function plotpsth(rvv::RVVector,binedges::RealVector,cond::DataFrame;timeline=[0],colors=huecolors(nrow(cond)),title="")
    msexc = psth(rvv,binedges,cond)
    plotpsth(msexc,timeline=timeline,colors=colors,title=title)
end
function plotpsth(msexc::DataFrame;timeline=[0],colors=[:auto],title="")
    @df msexc Plots.plot(:x,:m,ribbon=:se,group=:c,fillalpha=0.2,color=reshape(colors,1,:))
    vline!(timeline,line=(:grey),label="TimeLine",grid=false,xaxis=(factorunit(:Time)),yaxis=(factorunit(:Response)),title=(title))
end
function plotpsth(data::RealMatrix,x,y;color=:Reds,timeline=[0],hlines=[],layer=nothing)
    xms = x*SecondPerUnit*1000
    p=heatmap(xms,y,data,color=color,colorbar_title="Spike/Sec",xlabel="Time (ms)",ylabel="Depth (um)")
    vline!(p,timeline,color=:gray,label="TimeLine")
    if !isnothing(layer)
        lx = minimum(xms)+5
        hline!(p,[layer[k][1] for k in keys(layer)],linestyle=:dash,annotations=[(lx,layer[k][1],text(k,6,:gray20,:bottom)) for k in keys(layer)],linecolor=:gray30,legend=false)
    end
    return p
end

function plotsta(α,imagesize;delay=nothing,decor=false,color=:coolwarm,filter=Kernel.gaussian(2))
    d = isnothing(delay) ? "" : "_$(delay)"
    t = (decor ? "d" : "") * "STA$d"
    plotsta(reshape(α,imagesize),title=t,color=color,filter=filter)
end
function plotsta(α;title="",color=:coolwarm,filter=nothing)
    if !isnothing(filter)
        α = imfilter(α,filter)
    end
    plot(α,seriestype=:heatmap,color=color,ratio=:equal,yflip=true,leg=false,framestyle=:none,title=title)
end

function plotanalog(data;x=nothing,y=nothing,fs=0,xext=0,timeline=[0],xlabel="Time",xunit=:ms,cunit=:v,plottype=:heatmap,ystep=20,color=:coolwarm,layer=nothing)
    nd=ndims(data)
    if nd==1
        x=1:length(y)
        if fs>0
            x = x./fs.-xext
            if timeunit==:ms
                x*=1000
            end
        end
        ylim=maximum(abs.(y))
        p=plot(x,y,ylims=(-ylim,ylim))
    elseif nd==2
        if isnothing(x)
            x=1:size(data,2)
            if fs>0
                x = x./fs.-xext
                if xunit==:ms
                    x*=1000
                end
            end
        end
        if cunit==:v
            lim = maximum(abs.(data))
            clim = (-lim,lim)
        elseif cunit == :sp
            lim = maximum(data)
            clim = (0,lim)
        else
            lim = maximum(data)
            clim = :auto

        end
        if plottype==:heatmap
            if isnothing(y)
                y = (1:size(data,1))*ystep
            end
            p=heatmap(x,y,data,color=color,clims=clim,xlabel="$xlabel ($xunit)")
        else
            p=plot(x,data',legend=false,color_palette=color,grid=false,ylims=clim,xlabel="$xlabel ($xunit)")
        end
    end
    !isempty(timeline) && vline!(p,timeline,line=(:grey),label="TimeLine")
    if !isnothing(layer)
        lx = minimum(x)+5
        hline!(p,[layer[k][1] for k in keys(layer)],linestyle=:dash,annotations=[(lx,layer[k][1],text(k,6,:gray20,:bottom)) for k in keys(layer)],linecolor=:gray30,legend=false)
    end
    return p
end

plotunitposition(spike::Dict;layer=nothing,color=nothing,alpha=0.4,title="") = plotunitposition(spike["unitposition"],unitgood=spike["unitgood"],chposition=spike["chposition"],unitid=spike["unitid"],layer=layer,color=color,alpha=alpha,title=title)
function plotunitposition(unitposition;unitgood=[],chposition=[],unitid=[],layer=nothing,color=nothing,alpha=0.4,title="")
    nunit = size(unitposition,1);ngoodunit = isempty(unitgood) ? nunit : count(unitgood);us = "$ngoodunit/$nunit"
    xlim = isempty(chposition) ? (minimum(unitposition[:,1])-5,maximum(unitposition[:,1])+5) : (minimum(chposition[:,1])-5,maximum(chposition[:,1])+5)
    p = plot(legend=:topright,xlabel="Position_X (um)",ylabel="Position_Y (um)",xlims=xlim)
    if !isempty(chposition)
        scatter!(p,chposition[:,1],chposition[:,2],markershape=:rect,markerstrokewidth=0,markersize=2,color=:grey60,label="Electrode")
    end
    if isnothing(color)
        if !isempty(unitgood)
            color = map(i->i ? :darkgreen : :gray30,unitgood)
        else
            color = :gray30
        end
        if !isnothing(alpha)
            color = coloralpha.(parse.(RGB,color),alpha)
        end
    end
    if !isempty(unitid)
        scatter!(p,unitposition[:,1],unitposition[:,2],label=us,color=color,markerstrokewidth=0,markersize=6,series_annotations=text.(unitid,3,:gray10,:center),title=title)
    else
        scatter!(p,unitposition[:,1],unitposition[:,2],label=us,color=color,markerstrokewidth=0,markersize=5,title=title)
    end
    if !isnothing(layer)
        lx = xlim[1]+2
        hline!(p,[layer[k][1] for k in keys(layer)],linestyle=:dash,annotations=[(lx,layer[k][1],text(k,6,:gray20,:bottom)) for k in keys(layer)],linecolor=:gray30,legend=false)
    end
    return p
end

function plotcircuit(unitposition,projs,suidx;unitid=[],eunits=[],iunits=[],layer=nothing)
    g = SimpleDiGraphFromIterator(Edge(i) for i in projs)
    nn = nv(g);np=ne(g)
    nunit = size(unitposition,1);nunitpair=binomial(nunit,2);gs = "$nunit: $np/$nunitpair($(round(np/nunitpair*100,digits=3))%)"
    xlim = (minimum(unitposition[:,1])-5,maximum(unitposition[:,1])+5)
    ylim = (minimum(unitposition[:,2]),maximum(unitposition[:,2]))
    p = plot(legend=:topright,xlabel="Position_X (um)",ylabel="Position_Y (um)",xlims=xlim,grid=false)

    for (i,j) in projs
        t=vcat(unitposition[suidx[i:i],:],unitposition[suidx[j:j],:])
        plot!(p,t[:,1],t[:,2],linewidth=0.3,color=:gray50,arrow=arrow(:closed,:head,0.45,0.12))
    end

    color = fill(:gray30,nunit)
    color[suidx] .= :darkgreen
    if !isempty(eunits)
        color[suidx[eunits]] .= :darkred
    end
    if !isempty(iunits)
        color[suidx[iunits]] .= :darkblue
    end
    if !isempty(unitid)
        scatter!(p,unitposition[:,1],unitposition[:,2],label=gs,color=color,alpha=0.4,markerstrokewidth=0,markersize=6,series_annotations=text.(unitid,3,:gray10,:center),legend=false)
    else
        scatter!(p,unitposition[:,1],unitposition[:,2],label=gs,color=color,alpha=0.4,markerstrokewidth=0,markersize=5,legend=false)
    end
    if !isnothing(layer)
        hline!(p,[layer[k][1] for k in keys(layer)],linestyle=:dash,annotations=[(xlim[1]+2,layer[k][1],text(k,6,:gray20,:bottom)) for k in keys(layer)],linecolor=:gray30,legend=false)
    end
    annotate!(p,[(xlim[2]-6,ylim[2],text(gs,6,:gray20,:bottom))])
    return p
end

# function savefig(fig,filename::AbstractString;path::AbstractString="",format::AbstractString="svg")
#     f = joinpath(path,"$filename.$format")
#     if !ispath(path)
#         mkpath(path)
#     end
#     if format=="svg"
#         format = "$format+xml"
#     end
#     open(f, "w") do io
#         writemime(io,"image/$format",fig)
#     end
# end
#
# function savefig(fig::Gadfly.Plot,filename::AbstractString;path::AbstractString="",format::AbstractString="svg",width=22cm,height=13cm,dpi=300)
#     f = joinpath(path,"$filename.$format")
#     if !ispath(path)
#         mkpath(path)
#     end
#     if format=="svg"
#         format = SVG(f,width,height)
#     elseif format=="png"
#         format = PNG(f,width,height,dpi=dpi)
#     elseif format=="pdf"
#         format = PDF(f,width,height,dpi=dpi)
#     end
#     draw(format,fig)
# end
