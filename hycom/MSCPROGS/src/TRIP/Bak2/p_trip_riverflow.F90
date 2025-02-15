! --- -------------------------------------------------------------------
! --- River routine trip_riverflow
! --- -------------------------------------------------------------------
! --- Program to "connect the dots" in the trip05 river path database.
! --- For each TRIP point, data from a runoff database is assigned, and 
! --- a simple river transport model is used to calculate the flow from 
! --- the point towards the river outlets. All calculation is done on the 
! --- TRIP grid.
! ---
! --- For now this routine uses ERA40 data, but it can easily be changed 
! --- to other runoff products.
! ---
! --- Output from this routine is:
! --- netcdf file with runoff and river volume per grid cell.
! --- TODO: hycom river file
! --- -------------------------------------------------------------------
! --- Prerequisites:
! --- 1) river_weights must be called before running this 
! ---    routine - to get the mapping from runoff grid -> TRIP grid
! --- 2) ERA40 runoff data must be availabel in either the directory "./ERA40/",
! ---    or in the directory set in env variable ERA40_PATH
! --- 2) TRIP data base must be availabel in either the directory "./Data/",
! ---    or in the directory set in env variable TRIP_PATH
! --- -------------------------------------------------------------------

program trip_flow
   use mod_year_info
   use netcdf
   use m_handle_err
   use m_read_runoff_era40, only : nrolon=>nlon, nrolat=>nlat, &
                                   rolat => lat, rolon => lon, &
                                   init_runoff_era40, read_runoff_era40
   use mod_trip
   implicit none
!#if defined (TRIP05)
!   integer, parameter :: nx=720, ny=360 ! grid dimensions 0.5 X 0.5 grid
!   real,    parameter :: dx=0.5, dy=0.5 ! grid spacing
!   character(len=*), parameter :: tfile='trip05.txt'
!   character(len=720) txtline
!#elif defined (TRIP)
!   integer, parameter :: nx=360, ny=180 ! grid dimensions 1 X 1 grid
!   real,    parameter :: dx=1., dy=1. ! grid spacing
!   character(len=*), parameter :: tfile='trip.txt'
!   character(len=360) txtline
!#endif
!   character(len=200) :: pathtrip, cenv


   real, parameter :: rearth=6372.795477598 ! Quadratic mean radius (km)
   real, parameter :: radian=57.2957795
   real, parameter :: ueff  = 0.35

   character(len=4) :: cyy

   integer, dimension(nx,ny) :: destinationx, destinationy,lmask
!   real, dimension(nx) :: lon
!   real, dimension(ny) :: lat

   integer :: ios
   integer :: i,j,i2,j2,i3,j3, niter,k, itl,im1,ip1

   real    :: sumcatch(nx*ny)
   real    :: newvol(nx,ny),oldvol(nx,ny),riverflux(nx,ny), &
              riverflux_clim(nx,ny,12), &
              ro_clim       (nx,ny,12), &
              vol_clim      (nx,ny,12)
   integer :: numclim
   real    :: triprunoff(nx,ny)
   real    :: tmplline(nx), tmp
   logical :: rmask(nx,ny)
   integer :: ocnmask(nx,ny)
   integer :: nriver

   integer              :: maxrocells,nxro,nyro
   real   , allocatable :: roweights(:,:,:)
   integer, allocatable :: nrocells(:,:), romapi(:,:,:), romapj(:,:,:)
   real   , allocatable :: ro(:,:)

   integer :: itrip,jtrip,destj,desti,nc_lastyear
   real    :: triparea(nx,ny),tmparea
   real    :: dt, dist, F

   integer :: ncid, varid, xdim, ydim, recdim, dims3D(3), irec, varidro, &
              varidriv, dims2D(2), varidrivcatch, rivdim, varidrec
   logical :: ex, asc_info=.false., excatch
   real :: rtime, spinuptime
   integer :: startyear

    integer, parameter :: nriver_catch=30, maxtimes=5000
    real, allocatable, dimension(:,:) :: &
       river_outlets_flux
    real, allocatable, dimension(:) :: &
       river_outlets_lon,river_outlets_lat,river_outlets_catch
    integer, allocatable, dimension(:) :: &
       river_outlets_i,river_outlets_j

   integer :: iyear, imonth, idom

   real, external :: spherdist
   logical, parameter  :: ncdump=.true. ! put to netcdf file for illustrations
   integer, parameter  :: moddump=5       ! step between each netcdf dump

   ! First initialize era 40 stuff - set up era40 path and lon/lat
   call init_runoff_era40()


   call init_trip()

   ! TODO: This should be done in trip_init - but for now there
   !       is som inconsistency between "flips" in riverweights/riverflow
   do j=1,ny
      lat(j) = 90-dx/2 - (j-1)*dy 
   end do
   do i=1,nx
      lon(i) = (i-1)*dx + dx/2
   end do
      

   ! "Flip" the data so that increasing j is northwards
   do j=1,ny
      tmp=lat(j) 
      lat(j)=lat(ny-j+1)
      lat(ny-j+1)=tmp

      tmplline=direction(:,j)
      direction(:,j)=direction(:,ny-j+1)
      direction(:,ny-j+1)=tmplline
   end do


   ! Read the cell info schtuff
   !open(10,file='rw_maxncells.asc',status='old')
   !read(10,*) maxrocells
   !close(10)

   inquire(exist=ex,file='rw_cellinfo.uf')
   if (.not. ex) then 
      print *,'Could not find rw_cellinfo.uf - run trip_weights first'
      stop
   end if


   open(10,file='rw_cellinfo.uf'   ,form='unformatted',status='old')
   read(10)  maxrocells,nxro,nyro
   close(10)
   print *,'Max number of cells, ronx, rony: ',maxrocells,nxro,nyro
   allocate(nrocells (nxro,nyro))
   allocate(romapi   (nxro,nyro,maxrocells))
   allocate(romapj   (nxro,nyro,maxrocells))
   allocate(roweights(nxro,nyro,maxrocells))

   ! Read the weights, ncells and mapping from a binary file
   open(10,file='rw_cellinfo.uf'   ,form='unformatted',status='old')
   read(10)  maxrocells,nxro,nyro       , &
             nrocells                   , &
             romapi   (:,:,1:maxrocells), &
             romapj   (:,:,1:maxrocells), &
             roweights(:,:,1:maxrocells)
    close(10)


    ! Trip grid cell areas (approximate)
    do j=1,ny
    do i=1,nx
       triparea(i,j)=sin(dx/radian)*sin(dy/radian)*sin(lat(j)/radian)*rearth**2*1e6
    end do
    end do
    allocate(ro   (nxro,nyro))



    ! Initialize potential river outlets
    nriver=0
    rmask=.false.
    do j=2,ny-1
    do i=1,nx
    if (direction(i,j)==9.or.direction(i,j)==0) then
       ip1=mod(i,nx)+1
       im1=mod(nx+i-2,nx)+1

       if ( (any(direction(im1,j-1:j+1)>0.and.direction(im1,j-1:j+1)<9)) .or.&
            (any(direction(i  ,j-1:j+1)>0.and.direction(i  ,j-1:j+1)<9)) .or.&
            (any(direction(ip1,j-1:j+1)>0.and.direction(ip1,j-1:j+1)<9)) ) then

          nriver=nriver+1
          rmask(i,j)=.true.
       end if
    end if
    end do
    end do
    print *,'Potential number of rivers:',nriver



    ! Read top 30 river outlets based on catchment data
    !Top rivers by catchment
    inquire(exist=excatch,file='catchment.asc') 
    if (excatch) then
       allocate(river_outlets_i    (nriver_catch))
       allocate(river_outlets_j    (nriver_catch))
       allocate(river_outlets_lon  (nriver_catch))
       allocate(river_outlets_lat  (nriver_catch))
       allocate(river_outlets_catch(nriver_catch))
       allocate(river_outlets_flux (maxtimes,nriver_catch))
       open(10,file='catchment.asc',status='old')
       do i=1,nriver_catch
          !read(10,'(2i5,2f14.5,e14.4)') basinx(i),basiny(i), &
          !   lon(basinx(i)),lat(basiny(i)), sumcatch(i)
          read(10,*) river_outlets_i(i),river_outlets_j(i), &
             river_outlets_lon(i),river_outlets_lat(i),     &
             river_outlets_catch(i)

          !print *,river_outlets_i(i),river_outlets_j(i),river_outlets_lat(i), &
          !        lat(river_outlets_j(i))

          ! Check for "flip" and river outlet error
          if (river_outlets_lat(i) /=  lat(river_outlets_j(i))) then
             print *,river_outlets_i(i),river_outlets_j(i),river_outlets_lat(i), &
                     lat(river_outlets_j(i))
             print *,'"Flip error" on lat variable'
             stop
          else if (.not.rmask(river_outlets_i(i),river_outlets_j(i)) ) then
             !This shouldnt happen either, so its a nice safety check
             print *,'river outlet apparently not in river mask?'
             stop
          end if
       end do
       close(10)
    end if


    !stop


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Main loop starts here


    print *,'River integration starts '
    oldvol=0. 
    newvol=0. 
    riverflux=0.
    startyear=1958
    dt=6*3600
    !spinuptime=3*365*4 ! 3 years
    spinuptime=0. ! 3 years
    riverflux_clim=0.
    vol_clim=0.
    ro_clim =0.
    numclim=0
    nc_lastyear=-1
    !do itl = 1,73000 ! 50*365*4 , 50 yrs
    !do itl = 1,200
    do itl = 1,5000



       ! convert itl*dt to time (in days)
       rtime=itl*dt/86400.

       call juliantodate(floor(rtime),iyear,imonth, idom, startyear,1,1)
       if (mod(itl,100)==0) then
          print '(a,i5,i3,i3)','Date ',iyear, imonth, idom
       end if
       !print *,itl,rtime, iyear, imonth


       ! Read one record of the runoff field
       call read_runoff_era40(startyear,rtime,ro,nxro,nyro)


       ! Assign runoff field to trip cells
       triprunoff=0.
       do j=1,nyro
       do i=1,nxro
          do k=1,nrocells(i,j)
             itrip   =romapi   (i,j,k)
             jtrip   =romapj   (i,j,k)
             tmparea =roweights(i,j,k)
             
             triprunoff(itrip,jtrip)= triprunoff(itrip,jtrip) +  &
                ro(i,j)*tmparea*1e6 ! triparea in km^2  units: m^3/s
          end do
       end do
       end do



          

       if (asc_info) then
          print *,'Max trip area           (m^2        ):',maxval(triparea)
          print *,'Max trip runoff         (m^3/s      ):',maxval(triprunoff)
          print *,'Max trip runoff per area(m^3/(s*m^2)):',maxval(triprunoff/triparea)
       end if


       ! Mass budget of each grid cell
       oldvol=newvol
       do j=2,ny-1
       do i=1,nx
       if (direction(i,j)/=9.and.direction(i,j)/=0) then ! land point with throughflow


          ! lat direction of flow
          destj=j
          if     (direction(i,j)==1.or.direction(i,j)==2.or.  direction(i,j)==8) then
             destj=j-1
          elseif (direction(i,j)==4.or.direction(i,j)==5.or.  direction(i,j)==6) then
             destj=j+1
          end if

          ! lon direction of flow
          desti=i
          if     (direction(i,j)==2.or.direction(i,j)==3.or.  direction(i,j)==4) then
             desti=mod(i,nx)+1
          elseif (direction(i,j)==6.or.direction(i,j)==7.or.  direction(i,j)==8) then
             desti=mod(nx+i-2,nx)+1
          end if

          ! Distance between grid cell centers
          !print *,i,j,desti,destj
          dist=spherdist(lon(i),lat(j),lon(desti),lat(destj))

          ! Flow from one cell to the downstream neighbour
          ! (Miller et al, J. Clim, 1994, "Continental-Scale River Flow in Climate models")
          F=oldvol(i,j)*ueff/dist

          ! New mass in this cell
          newvol(i,j)=newvol(i,j)+(triprunoff(i,j)-F)*dt

          !if (triprunoff(i,j)>0.) print *,F,dt,triprunoff(i,j)


          ! New mass in downstream cell (no runoff added here, see above)
          newvol(desti,destj)=newvol(desti,destj)+F*dt

       end if
       end do
       end do


       ! Calculate flux in river outlets
       do j=1,ny
       do i=1,nx
       if (direction(i,j)==9.or.direction(i,j)==0) then ! land point with throughflow
          riverflux(i,j)=(newvol(i,j)-oldvol(i,j))/dt
          newvol(i,j)=0. ! NB 
       end if
       end do
       end do
       where (newvol<0.) newvol=0. ! check out the reason for this

       ! Climatology
       if (rtime>spinuptime) then
          do j=1,ny
          do i=1,nx
             if (direction(i,j)==9.or.direction(i,j)==0) then ! land point with throughflow
                riverflux_clim(i,j,imonth)=riverflux_clim(i,j,imonth) + &
                                            riverflux(i,j)
             end if
             vol_clim(i,j,imonth)= vol_clim(i,j,imonth)+ &
                newvol(i,j)
             ro_clim (i,j,imonth)= ro_clim (i,j,imonth)+ &
                triprunoff(i,j)
          end do
          end do
          numclim=numclim+1
          !print *,minval(newvol),maxval(newvol)
       end if


       if (asc_info) then
          print *,'Max vol diff            (m^3/s      ):',maxval(newvol-oldvol)/dt
          print *,'Max River volume        (m^3        ):',maxval(newvol)
          print *,'Max River flux          (m^3/s      ):',maxval(riverflux)
          print *,'--------------------- END OF LOOP ----------------'
       end if


       ! Put in a netcdf file at regular intervals - 2D maps
       if (mod(itl,moddump)==0 .and. ncdump) then


          !Replace file on first try
          ex=(itl==moddump) 

          ! Also replace on year changeover
          ex=ex .or. nc_lastyear /= iyear

          if (ex) then
             write(cyy,'(i4.4)') iyear
             call handle_err(nf90_create('trip_era40_'//cyy//'.nc',NF90_CLOBBER,ncid))
             call handle_err(nf90_def_dim(ncid,'lon'    ,nx,xdim))
             call handle_err(nf90_def_dim(ncid,'lat'    ,ny,ydim))
             call handle_err(nf90_def_dim(ncid,'record',nf90_unlimited,recdim))
             if (excatch) call handle_err(nf90_def_dim(ncid,'river_catchment',nriver_catch,rivdim))
             dims3d=(/xdim,ydim,recdim/)
             dims2d=(/rivdim,recdim/)

             call handle_err(NF90_DEF_VAR(ncid,'lon',NF90_Float,xdim,varid))
             call handle_err(NF90_ENDDEF(ncid))
             call handle_err(NF90_PUT_VAR(ncid,varid,lon))

             call handle_err(NF90_REDEF(ncid))
             call handle_err(NF90_DEF_VAR(ncid,'mask',NF90_INT,(/xdim,ydim/),varid))
             call handle_err(NF90_ENDDEF(ncid))
             call handle_err(NF90_PUT_VAR(ncid,varid,ocnmask))

             call handle_err(NF90_REDEF(ncid))
             call handle_err(NF90_DEF_VAR(ncid,'lat',NF90_Float,ydim,varid))
             call handle_err(NF90_ENDDEF(ncid))
             call handle_err(NF90_PUT_VAR(ncid,varid,lat))

             if (excatch) then
                call handle_err(NF90_REDEF(ncid))
                call handle_err(NF90_DEF_VAR(ncid,'riverbycatch_lon',NF90_Float,rivdim,varid))
                call handle_err(NF90_ENDDEF(ncid))
                call handle_err(NF90_PUT_VAR(ncid,varid,river_outlets_lon))

                call handle_err(NF90_REDEF(ncid))
                call handle_err(NF90_DEF_VAR(ncid,'riverbycatch_lat',NF90_Float,rivdim,varid))
                call handle_err(NF90_ENDDEF(ncid))
                call handle_err(NF90_PUT_VAR(ncid,varid,river_outlets_lat))
             end if

             call handle_err(NF90_REDEF(ncid))
             call handle_err(NF90_DEF_VAR(ncid,'runoff',NF90_Float,dims3D,varidro))
             call handle_err(NF90_PUT_ATT(ncid,varidro,'units','m3 s-1'))
             call handle_err(NF90_DEF_VAR(ncid,'volume',NF90_Float,dims3D,varid))
             call handle_err(NF90_PUT_ATT(ncid,varid,'units','m3'))
             call handle_err(NF90_DEF_VAR(ncid,'river',NF90_Float,dims3D,varidriv))
             call handle_err(NF90_PUT_ATT(ncid,varid,'units','m3 s-1'))
             if (excatch) &
                call handle_err(NF90_DEF_VAR(ncid,'riverbycatch',NF90_Float,dims2D,varidrivcatch))
             call handle_err(NF90_DEF_VAR(ncid,'record',NF90_Float,recdim,varidrec))
             call handle_err(NF90_ENDDEF(ncid))
             irec=1
          else
             write(cyy,'(i4.4)') iyear
             call handle_err(nf90_open('trip_era40_'//cyy//'.nc',NF90_WRITE,ncid))
             !call handle_err(nf90_open('test.nc',NF90_WRITE,ncid))
             call handle_err(nf90_inq_dimid(ncid, 'lon', xdim))
             call handle_err(nf90_inq_dimid(ncid, 'lat', ydim))
             call handle_err(nf90_inq_dimid(ncid, 'record', recdim))
             if (excatch) then 
                call handle_err(nf90_inq_dimid(ncid, 'river_catchment', rivdim))
                call handle_err(Nf90_inq_varid(ncid, 'riverbycatch', varidrivcatch))
             end if
             call handle_err(nf90_Inquire_Dimension(ncid, recdim, len=irec))
             dims3d=(/xdim,ydim,recdim/)
             dims2d=(/rivdim,recdim/)
             call handle_err(Nf90_inq_varid(ncid, 'runoff', varidro))
             call handle_err(Nf90_inq_varid(ncid, 'volume', varid))
             call handle_err(Nf90_inq_varid(ncid, 'river', varidriv))
             call handle_err(Nf90_inq_varid(ncid, 'record', varidrec))

             irec=irec+1
          end if
          call handle_err(NF90_PUT_VAR(ncid,varidrec,startyear+rtime/365., &
                                       start=(/irec/)))
          call handle_err(NF90_PUT_VAR(ncid,varid,newvol(1:nx,1:ny), &
                                       start=(/1,1,irec/)))
          call handle_err(NF90_PUT_VAR(ncid,varidro,triprunoff(1:nx,1:ny), &
                                       start=(/1,1,irec/)))
          call handle_err(NF90_PUT_VAR(ncid,varidriv,riverflux(1:nx,1:ny), &
                                       start=(/1,1,irec/)))
          if (excatch) then
          do i=1,nriver_catch
             river_outlets_flux (min(max(1,itl/moddump),maxtimes),i)= &
                riverflux(river_outlets_i(i),river_outlets_j(i))
             !if (i==1) then
             !   print *, river_outlets_flux (min(max(1,itl/moddump),maxtimes),i)
             !end if
             call handle_err(NF90_PUT_VAR(ncid,varidrivcatch, &
                             river_outlets_flux (min(max(1,itl/moddump),maxtimes),:), &
                                          start=(/1,irec/)))
          end do
          end if


          call handle_err(nf90_close(ncid))
          nc_lastyear=iyear
       end if
    enddo ! main loop
    !call handle_err(nf90_close(ncid))






    ! Dump climatology if calculated
    if (rtime>spinuptime+ 366) then
       riverflux_clim=riverflux_clim/numclim
       ro_clim=ro_clim/numclim
       vol_clim=vol_clim/numclim

       call handle_err(nf90_create('trip_era40_clim.nc',NF90_CLOBBER,ncid))
       call handle_err(nf90_def_dim(ncid,'lon'    ,nx,xdim))
       call handle_err(nf90_def_dim(ncid,'lat'    ,ny,ydim))
       call handle_err(nf90_def_dim(ncid,'record',12,recdim))
       dims3d=(/xdim,ydim,recdim/)

       call handle_err(NF90_DEF_VAR(ncid,'lon',NF90_Float,xdim,varid))
       call handle_err(NF90_ENDDEF(ncid))
       call handle_err(NF90_PUT_VAR(ncid,varid,lon))

       call handle_err(NF90_REDEF(ncid))
       call handle_err(NF90_DEF_VAR(ncid,'mask',NF90_INT,(/xdim,ydim/),varid))
       call handle_err(NF90_ENDDEF(ncid))
       call handle_err(NF90_PUT_VAR(ncid,varid,ocnmask))

       call handle_err(NF90_REDEF(ncid))
       call handle_err(NF90_DEF_VAR(ncid,'rtst',NF90_Float,(/xdim,ydim/),varid))
       call handle_err(NF90_ENDDEF(ncid))
       call handle_err(NF90_PUT_VAR(ncid,varid,ro_clim(:,:,1)))

       call handle_err(NF90_REDEF(ncid))
       call handle_err(NF90_DEF_VAR(ncid,'lat',NF90_Float,ydim,varid))
       call handle_err(NF90_ENDDEF(ncid))
       call handle_err(NF90_PUT_VAR(ncid,varid,lat))

       call handle_err(NF90_REDEF(ncid))
       call handle_err(NF90_DEF_VAR(ncid,'volume',NF90_Float,dims3D,varid))
       call handle_err(NF90_ENDDEF(ncid))
       call handle_err(NF90_PUT_VAR(ncid,varid ,vol_clim,start=(/1,1,1/)))

       call handle_err(NF90_REDEF(ncid))
       call handle_err(NF90_DEF_VAR(ncid,'runoff',NF90_Float,dims3D,varidro))
       call handle_err(NF90_DEF_VAR(ncid,'river',NF90_Float,dims3D,varidriv))
       call handle_err(NF90_ENDDEF(ncid))

       do k=1,12 
          call handle_err(NF90_PUT_VAR(ncid,varidro,ro_clim(:,:,k),start=(/1,1,k/)))
          call handle_err(NF90_PUT_VAR(ncid,varidriv,riverflux_clim(:,:,k),start=(/1,1,k/)))
       end do
       call handle_err(NF90_CLOSE(ncid))
    end if






   end program
