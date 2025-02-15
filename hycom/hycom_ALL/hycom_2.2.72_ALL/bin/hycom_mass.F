      PROGRAM FMASS
      IMPLICIT NONE
C
C  hycom_mass     - Usage:  hycom_mass file.a [[grid.a] mask.a]
C  hycom_mass_rms - Usage:  hycom_mass_rms file.a [[grid.a] mask.a]
C  hycom_mass_sum - Usage:  hycom_mass_tot file.a [[grid.a] mask.a]
C
C                 prints the min, mean, std.dev. and max of all fields in file.a
C                 hycom_mass_rms replaces std.dev. with rms.
C                 hycom_mass_tot replaces mean with sum (mean*area).
C
C                 grid.a is a hycom grid file, default regional.grid.a.
C                 Note that the corresponding grid.b must also exist.
C
C                 mask.a contains an optional mask array, that turns
C                 off sampling anywhere it is 2.0**100 (data void).
C                 Note that grid.a must be specified if mask.a is used.
C
C                 idm,jdm are taken from grid.a and the input array
C                 is assumed to be on the p-grid (i.e. plat from grid.a
C                 represents the field's latitude).
C
C  file.a is assumed to contain idm*jdm 32-bit IEEE real values for
C   each array, in standard f77 element order, followed by padding
C   to a multiple of 4096 32-bit words, but otherwise with no control
C   bytes/words, and input values of 2.0**100 indicating a data void.
C
C  this version for "serial" Unix systems.
C
C  Alan J. Wallcraft,  Naval Research Laboratory,  January 2001.
C
      REAL*4, ALLOCATABLE :: A(:,:),AMSK(:,:),PSC2(:,:)
      REAL*4              :: PAD(4096)
      INTEGER       IOS,L
      INTEGER       IARGC
      INTEGER       NARG
      CHARACTER*240 CARG
C
      LOGICAL       LRMS,LSUM
      INTEGER       IDM,JDM,NPAD
      REAL*4        CELL
      CHARACTER*6   CVARIN
      CHARACTER*240 CFILE,CFILEG,CFILEM,CFILEB
C
C     READ ARGUMENTS.
C
      CALL GETARG(0,CARG)
      L = LEN_TRIM(CARG)
      LRMS = CARG(L-3:L).EQ.'_rms'
      LSUM = CARG(L-3:L).EQ.'_sum'
C
      NARG = IARGC()
C
      IF     (NARG.EQ.1) THEN
        CALL GETARG(1,CFILE)
        CFILEG = 'regional.grid.a'
        CFILEM = 'NONE'
      ELSEIF (NARG.EQ.2) THEN
        CALL GETARG(1,CFILE)
        CALL GETARG(2,CFILEG)
        CFILEM = 'NONE'
      ELSEIF (NARG.EQ.3) THEN
        CALL GETARG(1,CFILE)
        CALL GETARG(2,CFILEG)
        CALL GETARG(3,CFILEM)
      ELSE
        WRITE(6,*) 
     +   'Usage:  hycom_mass file.a [grid.a] [mask.a]'
        CALL EXIT(1)
      ENDIF
C
C     GET IDM,JDM FROM grid.b.
C
      CFILEB = CFILEG(1:LEN_TRIM(CFILEG)-1) // 'b'
C
      OPEN(UNIT=11,FILE=CFILEB,FORM='FORMATTED',
     &     STATUS='OLD',ACTION='READ')
C
      READ( 11,*) IDM,CVARIN
      IF (CVARIN.NE.'idm   ') THEN
        WRITE(6,*) 'hycom_mass: bad header file ',
     &             CFILEB(1:LEN_TRIM(CFILEB))
        CALL EXIT(2)
      ENDIF
      READ( 11,*) JDM,CVARIN
      IF (CVARIN.NE.'jdm   ') THEN
        WRITE(6,*) 'hycom_mass: bad header file ',
     &             CFILEB(1:LEN_TRIM(CFILEB))
        CALL EXIT(2)
      ENDIF
C
      CLOSE(UNIT=11)
C
      NPAD = 4096 - MOD(IDM*JDM,4096)
      IF     (NPAD.EQ.4096) THEN
        NPAD = 0
      ENDIF
C
      ALLOCATE( A(IDM,JDM), STAT=IOS )
      IF     (IOS.NE.0) THEN
        WRITE(6,*) 'Error in hycom_zonal: could not allocate ',
     +             IDM*JDM,' words for A'
        CALL EXIT(2)
      ENDIF
      ALLOCATE( AMSK(IDM,JDM), STAT=IOS )
      IF     (IOS.NE.0) THEN
        WRITE(6,*) 'Error in hycom_zonal: could not allocate ',
     +             IDM*JDM,' words for AMSK'
        CALL EXIT(2)
      ENDIF
      ALLOCATE( PSC2(IDM,JDM), STAT=IOS )
      IF     (IOS.NE.0) THEN
        WRITE(6,*) 'Error in hycom_zonal: could not allocate ',
     +             IDM*JDM,' words for PSC2'
        CALL EXIT(2)
      ENDIF
C
      CALL MASS(A,AMSK,PSC2,IDM,JDM,PAD,NPAD, 
     +          LRMS,LSUM, CFILE,CFILEG,CFILEM)
      CALL EXIT(0)
 5000 FORMAT(I4)
      END
      SUBROUTINE MASS(A,AMSK,PSC2,IDM,JDM, PAD,NPAD,
     +               LRMS,LSUM, CFILE,CFILEG,CFILEM)
      IMPLICIT NONE
C
      REAL*4     SPVAL
      PARAMETER (SPVAL=2.0**100)
C
      CHARACTER*240 CFILE,CFILEG,CFILEM
      LOGICAL       LRMS,LSUM
      INTEGER       IDM,JDM,NPAD
      REAL*4        A(IDM,JDM),AMSK(IDM,JDM),PSC2(IDM,JDM),PAD(NPAD)
C
C     MOST OF WORK IS DONE HERE.
C
#ifdef sun
      INTEGER      IR_ISNAN
C
#endif
      CHARACTER*18 CASN
      INTEGER      LEN_TRIM
      INTEGER      I,J,K,IOS,NRECL
      REAL*4       AMN,AMX,AVE,AVERMS,STD
      REAL*8       SUMA,SUMS,SUMT,SUMTR(2)
#ifdef CRAY
      INTEGER*8    IU8,IOS8
#endif
C
C     INPUT MASK ARRAY.
C
      INQUIRE( IOLENGTH=NRECL) A,PAD
C
      IF     (CFILEM.EQ.'NONE') THEN
        AMSK(:,:) = 0.0
      ELSE
        OPEN(UNIT=11, FILE=CFILEM, FORM='UNFORMATTED', STATUS='OLD',
     +           ACCESS='DIRECT', RECL=NRECL, IOSTAT=IOS)
        IF     (IOS.NE.0) THEN
          write(6,*) 'Error: can''t open ',CFILEM(1:LEN_TRIM(CFILEM))
          write(6,*) 'ios   = ',ios
          write(6,*) 'nrecl = ',nrecl
          CALL EXIT(3)
        ENDIF
C
        READ(11,REC=1,IOSTAT=IOS) AMSK
#ifdef ENDIAN_IO
        CALL ENDIAN_SWAP(AMSK,IDM*JDM)
#endif
        IF     (IOS.NE.0) THEN
          WRITE(6,*) 'can''t read ',CFILEM(1:LEN_TRIM(CFILEM))
          CALL EXIT(4)
        ENDIF
      ENDIF
C
      CLOSE(UNIT=11)
C
C     INPUT GRID ARRAYS.
C
      OPEN(UNIT=11, FILE=CFILEG, FORM='UNFORMATTED', STATUS='OLD',
     +         ACCESS='DIRECT', RECL=NRECL, IOSTAT=IOS)
      IF     (IOS.NE.0) THEN
        write(6,*) 'Error: can''t open ',CFILEG(1:LEN_TRIM(CFILEG))
        write(6,*) 'ios   = ',ios
        write(6,*) 'nrecl = ',nrecl
        CALL EXIT(3)
      ENDIF
C
      READ(11,REC=10,IOSTAT=IOS) A     ! pscx
#ifdef ENDIAN_IO
      CALL ENDIAN_SWAP(A,   IDM*JDM)
#endif
      IF     (IOS.NE.0) THEN
        WRITE(6,*) 'can''t read ',CFILEG(1:LEN_TRIM(CFILEG))
        CALL EXIT(4)
      ENDIF
C
      READ(11,REC=11,IOSTAT=IOS) PSC2  ! pscy
#ifdef ENDIAN_IO
      CALL ENDIAN_SWAP(PSC2,IDM*JDM)
#endif
      IF     (IOS.NE.0) THEN
        WRITE(6,*) 'can''t read ',CFILEG(1:LEN_TRIM(CFILEG))
        CALL EXIT(4)
      ENDIF
C
      PSC2(:,:) = PSC2(:,:)*A(:,:)  ! psc2=pscx*pscy
C
      CLOSE(UNIT=11)
C
C     OPEN INPUT FILE.
C
#ifdef CRAY
#ifdef t3e
      IF     (MOD(NRECL,4096).EQ.0) THEN
        WRITE(CASN,8000) NRECL/4096
 8000   FORMAT('-F cachea:',I4.4,':1:0')
        IU8 = 11
        CALL ASNUNIT(IU8,CASN,IOS8)
        IF     (IOS8.NE.0) THEN
          write(6,*) 'Error: can''t asnunit 11'
          write(6,*) 'ios  = ',ios8
          write(6,*) 'casn = ',casn
          CALL EXIT(5)
        ENDIF
      ENDIF
#else
      CALL ASNUNIT(11,'-F syscall -N ieee',IOS)
      IF     (IOS.NE.0) THEN
        write(6,*) 'Error: can''t asnunit 11'
        write(6,*) 'ios = ',ios
        CALL EXIT(5)
      ENDIF
#endif
#endif
      OPEN(UNIT=11, FILE=CFILE, FORM='UNFORMATTED', STATUS='OLD',
     +         ACCESS='DIRECT', RECL=NRECL, IOSTAT=IOS)
      IF     (IOS.NE.0) THEN
        write(6,*) 'Error: can''t open ',CFILE(1:LEN_TRIM(CFILE))
        write(6,*) 'ios   = ',ios
        write(6,*) 'nrecl = ',nrecl
        CALL EXIT(3)
      ENDIF
C
C     LOOP OVER ALL FIELDS.
C
      DO K= 1,9999
        READ(11,REC=K,IOSTAT=IOS) A
#ifdef ENDIAN_IO
        CALL ENDIAN_SWAP(A,IDM*JDM)
#endif
        IF     (IOS.NE.0) THEN
          IF     (K.EQ.1) THEN
            WRITE(6,*) 'can''t read ',CFILE(1:LEN_TRIM(CFILE))
            CALL EXIT(4)
          ELSE
            EXIT !k
          ENDIF
        ENDIF
C
        AMN  =  SPVAL
        AMX  = -SPVAL
        SUMT = 0.0
        SUMA = 0.0
        DO J= 1,JDM
          DO I= 1,IDM
            IF     (   A(I,J).NE.SPVAL .AND.
     +              AMSK(I,J).NE.SPVAL      ) THEN
              AMN  = MIN( AMN, A(I,J) )
              AMX  = MAX( AMX, A(I,J) )
              SUMA = SUMA    + A(I,J)*PSC2(I,J)
              SUMT = SUMT    +        PSC2(I,J)
            ENDIF
          ENDDO
        ENDDO
        IF     (K.EQ.1) THEN
          SUMTR(1) = SUMT
          SUMTR(2) = SUMT
        ELSE  !k>1
          SUMTR(1) = MIN( SUMT, SUMTR(1) )
          SUMTR(2) = MAX( SUMT, SUMTR(2) )
        ENDIF !k==1:else
        IF     (SUMT.NE.0.0) THEN
          AVE  = SUMA/SUMT
          IF     (LRMS) THEN
            AVERMS = 0.0
          ELSE
            AVERMS = AVE
          ENDIF
          SUMS = 0.0
          DO J= 1,JDM
            DO I= 1,IDM
              IF     (   A(I,J).NE.SPVAL .AND.
     +                AMSK(I,J).NE.SPVAL      ) THEN
                SUMS = SUMS  + (A(I,J)-AVERMS)**2*PSC2(I,J)
              ENDIF
            ENDDO
          ENDDO
          STD = SQRT(SUMS/SUMT)
        ELSE
          AVE = 0.0
          STD = 0.0
        ENDIF
        IF     (LRMS) THEN
          WRITE(6,'(a,1p4g16.6)')
     &      'min,mean,rms,mx=',AMN, AVE,STD,AMX
        ELSEIF (LSUM) THEN
          WRITE(6,'(a,1p4g16.6)')
     &      'min,sum,rms,max=',AMN,SUMA,STD,AMX
        ELSE
          WRITE(6,'(a,1p4g16.6)')
     &      'min,mean,std,mx=',AMN, AVE,STD,AMX
        ENDIF
      ENDDO !k
C
      IF     (SUMTR(1).EQ.SUMTR(2)) THEN
        WRITE(6,*)
        WRITE(6,*) K-1,' FIELDS PROCESSED (AREA = ',SUMT*1.D-6,' KM^2)'
        WRITE(6,*)
      ELSE
        WRITE(6,*)
        WRITE(6,*) K-1,' FIELDS PROCESSED (AREA = ',SUMTR(1)*1.D-6,
     &                 ' TO ',SUMTR(2)*1.D-6,' KM^2)'
        WRITE(6,*)
      ENDIF
C
      CLOSE(UNIT=11)
C
      RETURN
      END
