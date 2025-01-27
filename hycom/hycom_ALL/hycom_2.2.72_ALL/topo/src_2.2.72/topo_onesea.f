      program onesea
      use mod_za  ! HYCOM array I/O interface
      implicit none
c
      integer   i,ii,isea,j,jj,k,nsea
      real      hmaxa,hmaxb,hmina,hminb
      character preambl(5)*79,cline*80
c
c --- read in a hycom topography file,
c --- identify all "seas" not connected to the largest "sea".
c
      integer, allocatable :: ip(:,:),jp(:)
      real,    allocatable :: dh(:,:)
c
      call xcspmd  !input idm,jdm
      allocate( jp(    jdm) )
      allocate( ip(idm,jdm) )
      allocate( dh(idm,jdm) )
c
c --- read in a hycom topography file,
c
      call zhopen(51, 'formatted', 'old', 0)
      read (51,'(a79)') preambl
      read (51,'(a)')   cline
      close(unit=51)
      write(6,'(a/(a))') 'HEADER:',
     &                   preambl,cline(1:len_trim(cline)),' '
c
      i = index(cline,'=')
      read (cline(i+1:),*)   hminb,hmaxb
c
      call zaiost
      call zaiopn('old', 51)
      call zaiord(dh,ip,.false., hmina,hmaxa, 51)
      call zaiocl(51)
c
      if     (abs(hmina-hminb).gt.abs(hminb)*1.e-4 .or.
     &        abs(hmaxa-hmaxb).gt.abs(hmaxb)*1.e-4     ) then
        write(6,'(/ a / a,1p3e14.6 / a,1p3e14.6 /)')
     &    'error - .a and .b topography files not consistent:',
     &    '.a,.b min = ',hmina,hminb,hmina-hminb,
     &    '.a,.b max = ',hmaxa,hmaxb,hmaxa-hmaxb
        call zhflsh(6)
        stop
      endif
c
c --- create a land/sea mask.
c
      do j= 1,jdm
        jp(j) = 0
        do i= 1,idm
          if     (dh(i,j).lt.2.0**99) then
            ip(i,j) = 1
            jp(j)   = jp(j) + 1
          else
            ip(i,j) = 0
          endif
        enddo
      enddo
c
c     color fill the sea points, one color per sea.
c
      do k= 2,99999
c
c       find an unfilled sea point
c
        ii = 0
        do j= 1,jdm
          if     (jp(j).gt.0) then
            do i= 1,idm
              if     (ip(i,j).eq.1) then
                ii = i
                jj = j
                exit
              endif
            enddo !i
            if     (ii.eq.0) then
              jp(j) = 0  !no original sea points left in this row
            else
              exit
            endif
          endif
        enddo !j
        if     (ii.eq.0) then
          exit  !no original sea points left in array
        endif
c
c       flood-fill the sea that is connected to this point.
c
        call fill(ii,jj, k, ip,idm,jdm)
      enddo !k
c
c     how may seas?
c
      nsea = k-2
      if     (nsea.eq.0) then  !all-land
        write(6,'(/a/)')         'region is all land'
      elseif (nsea.eq.1) then  !one-sea
        write(6,'(/a/)')         'one connected sea only'
      else  !multiple seas
        write(6,'(/i6,a/)') nsea,' seas identified'
        do k= 2,nsea+1
          isea = 0
          do j= 1,jdm
            do i= 1,idm
              if     (ip(i,j).eq.k) then
                isea = isea + 1
              endif
            enddo !i
          enddo !j
          write(6,'(i9,a,f7.2,a)')
     &      isea,' point sea (',
     &      (isea*100.0)/real(idm*jdm),'% of points)'
          if     (isea.lt.(idm*jdm)/3) then  !non-primary sea
            do j= 1,jdm
              do i= 1,idm
                if     (ip(i,j).eq.k) then
                  write(6,'(a,2i5)') '          at i,j =',i,j
                endif
              enddo !i
            enddo !j
          endif
        enddo !k
      endif
      end
      recursive subroutine fill(i,j,k, ip,idm,jdm)
      implicit none
c
      integer i,j,k,idm,jdm
      integer ip(idm,jdm)
c
c     fill this point, if necessary, and then extend search n,s,e,w
c
      integer ii
c
      if     (ip(i,j).eq.1) then
*         write(6,*) 'fill - i,j = ',i,j
*         call flush(6)
        ip(i,j) = k
        if     (i.ne.  1) then
          call fill(i-1,j,  k, ip,idm,jdm)
        else
          call fill(idm,j,  k, ip,idm,jdm)  !must be periodic, i-1 for i=1
        endif
        if     (j.ne.  1) then
          call fill(i,  j-1,k, ip,idm,jdm)
        endif
        if     (i.ne.idm) then
          call fill(i+1,j,  k, ip,idm,jdm)
        else
          call fill(  1,j,  k, ip,idm,jdm)  !must be periodic, i+1 for i=idm
        endif
        if     (j.lt.jdm-1) then
          call fill(i,  j+1,k, ip,idm,jdm)
        elseif (j.eq.jdm-1) then
          call fill(i,  j+1,k, ip,idm,jdm)
          ii = idm-mod(i-1,idm)
          call fill(ii, j+1,k, ip,idm,jdm)  !might be arctic, same point
        else !j.eq.jdm
          ii = idm-mod(i-1,idm)
          call fill(ii, j-1,k, ip,idm,jdm)  !must  be arctic, same point
        endif
      elseif (ip(i,j).ne.0 .and. ip(i,j).ne.k) then
        write(6,*) 'error in fill, point in two seas: i,j =',i,j
        write(6,*) 'sea ',ip(i,j),', and sea ',k
        stop
      endif
      end
