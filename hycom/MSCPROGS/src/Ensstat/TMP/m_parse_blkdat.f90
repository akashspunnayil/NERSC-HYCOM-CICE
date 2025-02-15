module m_parse_blkdat
   logical, private, parameter :: master=.true.
   private :: blkini, blkinr, blkinvoid
contains

   
      subroutine parse_blkdat(cvar,vtype,realvar,intvar,blkfilein,imatch)
      implicit none
      character(len=6), intent(in)  :: cvar
      character(len=*), intent(in)  :: vtype
      integer,          intent(out) :: intvar
      real   ,          intent(out) :: realvar
      character(len=*), intent(in), optional :: blkfilein
      integer         , intent(in), optional :: imatch

      character(len=80) :: blkfile

      logical :: found,ex
      integer :: nmatch,imatch2

      if (present(blkfilein)) then
         blkfile=blkfilein
      else
         blkfile='blkdat.input'
      end if
      if (present(imatch)) then
         imatch2=imatch
      else
         imatch2=1
      end if



      inquire(exist=ex,file=trim(blkfile))

      nmatch=0
      if (ex) then
         open(99,file=trim(blkfile),status='old')


         ! Skip header
         read(99,*)
         read(99,*)
         read(99,*)
         read(99,*)

         found=.false.

         do while (.not.found)
            found = blkinvoid(cvar)

            if (found) then
               nmatch=nmatch+1
               !print *,found,nmatch,imatch2
               found=found.and.nmatch==imatch2
               !print *,found
            end if

         end do

         ! if found, read..
         if (found) then
            backspace(99)
            if (trim(vtype)=='integer') then
               call blkini(intvar,cvar)
            elseif (trim(vtype)=='real') then
               call blkinr(realvar,cvar,'(a6," =",f10.4," m")')
            else
               print *,'Dont know how to handle variable type '//trim(vtype)
               stop '(parse_blkdat)'
            end if
         else
            print *,'Cant find varable'
            stop '(parse_blkdat)'
         end if

         close(99)
      else
         print *,'Cant find '//trim(blkfile) 
         stop '(parse_blkdat)'
      end if
      end subroutine parse_blkdat




      subroutine blkinr(rvar,cvar,cfmt)
      !use mod_xc  ! HYCOM communication interface
      implicit none
      real      rvar
      character cvar*6,cfmt*(*)
!     read in one real value
      character*6 cvarin

      read(99,*) rvar,cvarin
      if (master) write(6,cfmt) cvarin,rvar
      !call flush(6)

      if     (cvar.ne.cvarin) then
        write(6,*) 
        write(6,*) 'error in blkinr - input ',cvarin, &
                            ' but should be ',cvar
        write(6,*) 
        !call flush(6)
        stop '(blkinr)'
      endif
      return
      end subroutine

      subroutine blkini(ivar,cvar)
      implicit none
      integer     ivar
      character*6 cvar
!     read in one integer value
      character*6 cvarin
 
      read(99,*) ivar,cvarin
      if (master) write(6,6000) cvarin,ivar
      !call flush(6)
 
      if     (cvar.ne.cvarin) then
        write(6,*) 
        write(6,*) 'error in blkini - input ',cvarin, &
                            ' but should be ',cvar
        write(6,*) 
        !call flush(6)
        stop '(blkini)'
      endif
      return
 6000 format(a6,' =',i6)
      end subroutine



      logical function blkinvoid(cvar)
      !use mod_xc  ! HYCOM communication interface
      implicit none
      real      rvar
      character cvar*6
!     read in one real value
      character*6 cvarin

      read(99,*) rvar,cvarin
      !print *,rvar,cvarin,cvar
      blkinvoid=trim(cvar)==trim(cvarin)
      end function


end module m_parse_blkdat
