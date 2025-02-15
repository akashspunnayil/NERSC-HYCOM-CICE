#!/bin/csh -f
#
set echo
#
# plot wind stress and curl from archs file.
#
setenv  ARCHVS ../expt_30.6/archs.input
setenv  NCARG_GKS_PS 306_1999_335_curl.ps
~wallcraf/hycom/ALL/plot/src/hycomproc << E-o-D
/scr/wallcraf/hycom/GOMd0.08/expt_30.6/data/SAVE/archs.1999_335_00.a
2.98 prs6
  0     'iexpt ' = experiment number x10 (000=from archive file)
  3     'yrflag' = days in year flag (0=360J16,1=366J16,3=366J01)
258     'idm   ' = longitudinal array size
175     'jdm   ' = latitudinal  array size
  1     'kdm   ' = number of layers
 25.0	'thbase' = reference density (sigma units)
  1 	'nperfr' = number of horizontal plots per frame
  2	'lalolb' = spacing of latitude/longitude labels
 -2     'lalogr' = spacing of latitude/longitude grid over land (<0 land+sea)
  4     'loclab' = location of the contour label (1=upr,2=lowr,3=lowl,4=upl)
 11	'locbar' = location of the color bar     (1[0-4]=vert,2[0-4]=horiz)
 10	'kpalet' = palete (0=none,1=pastel,2=sst,3=gaudy,4=2tone,5=fc,6=ifc)
  0	'smooth' = smooth fields before plotting (0=F,1=T)
  1	'mthin'  = mask thin layers from plots   (0=F,1=T)
  6	'i_th'   = draw only every i_th vector in every (i_th/2) row
  1	'iorign' = i-origin of plotted subregion
  1	'jorign' = j-origin of plotted subregion
  0	'idmp  ' = i-extent of plotted subregion (<=idm; 0 implies idm)
  0	'jdmp  ' = j-extent of plotted subregion (<=jdm; 0 implies jdm)
 -1.0   'botqq ' = bathymetry       contour int (<0 no plot; 0 from field)
 16.0   'flxqq ' = surf. heat  flux contour int (<0 no plot; 0 from field)
  0.0   'center' = median color
 -1.0   'empqq ' = surf. evap-pcip  contour int (<0 no plot; 0 from field)
  0.008 'txqq  ' = surf. x-stress   contour int (<0 no plot; 0 from field)
  0.0   'center' = median color
  0.008 'tyqq  ' = surf. y-stress   contour int (<0 no plot; 0 from field)
  0.0   'center' = median color
  4.0   'curlqq' = surf. str. curl  contour int (<0 no plot; 0 from field)
  0.0   'center' = median color
 -1.0   'icvqq ' = ice coverage     contour int (<0 no plot; 0 from field)
 -1.0   'ithqq ' = ice thickness    contour int (<0 no plot; 0 from field)
 -1.0   'ictqq ' = ice temperature  contour int (<0 no plot; 0 from field)
 -1.0   'sshqq ' = sea surf. height contour int (<0 no plot; 0 from field)
 -1.0   'bsfqq ' = baro. strmfn.    contour int (<0 no plot; 0 from field)
  0.0   'mthrsh' = mix lay velocity plot threshold (0.0 for no plot)
 -1.0   'bltqq ' = bnd. lay. thick. contour int (<0 no plot; 0 from field)
 -1.0   'mltqq ' = mix. lay. thick. contour int (<0 no plot; 0 from field)
 -1.0   'sstqq ' = mix. lay. temp.  contour int (<0 no plot; 0 from field)
 -1.0   'sssqq ' = mix. lay. saln.  contour int (<0 no plot; 0 from field)
 -1.0   'ssdqq ' = mix. lay. dens.  contour int (<0 no plot; 0 from field)
 -1     'kf    ' = first plot layer (=0 end layer plots; <0 label with layer #)
  1     'kl    ' = last  plot layer
  0.0   'vthrsh' = layer k velocity plot threshold (0.0 for no plot)
 -1.0   'infqq ' = layer k   i.dep. contour int (<0 no plot; 0 from field)
 -1.0   'thkqq ' = layer k   thick. contour int (<0 no plot; 0 from field)
 -0.1   'temqq ' = layer k   temp   contour int (<0 no plot; 0 from field)
 -0.01  'salqq ' = layer k   saln.  contour int (<0 no plot; 0 from field)
 -0.02  'tthqq ' = layer k   dens,  contour int (<0 no plot; 0 from field)
 -1.0   'sfnqq ' = layer k  strmfn. contour int (<0 no plot; 0 from field)
  0     'kf    ' = layer to plot (=0 end layer plots; <0 label with layer #)
 500.0	'depth ' = cross section plot depth
  1.0	'vstep ' = velocity contours (1.0 stairstep, to 0.0 gently curved)
  0.0	'velqq ' = vel  contour int (<0 no vel  plot; 0 from field)
  0.0	'center' = central contoured value (ignored if kpalet<2)
  0.0	'temqq ' = temp contour int (<0 no temp plot; 0 from field)
 11.2 	'center' = central contoured value (ignored if kpalet<2)
 -1.0	'salqq ' = saln contour int (<0 no saln plot; 0 from field)
 11.2 	'center' = central contoured value (ignored if kpalet<2)
 -1.0	'tthqq ' = dens contour int (<0 no dens plot; 0 from field)
 11.2 	'center' = central contoured value (ignored if kpalet<2)
  1.1	'trcqq ' = trcr contour int (<0 no trcr plot; 0 from field)
 55.0 	'center' = central contoured value (ignored if kpalet<2)
  2	'mxlflg' = plot mixed layer (0=no-plot,1=plot,2=smooth-plot)
  4     'kpalet' = palete (0=none,1=pastel,2=sst,3=gaudy,4=2tone,5=fc,6=ifc)
  0	'noisec' = number of i cross sections
  0     'nojsec' = number of j cross sections
E-o-D
