VPATH = .:RCS:Build/

.SUFFIXES:
.SUFFIXES: .o .F90 .f90 .F .f .H .h  .c


# Tests dont work with unix make ? (works with gmake ...)
include ../Make.Inc/make.inc

# This is the hycom utility library
# NB: Path is relative to TMP dir
LIBS:= -L../../../lib/ -lhycnersc $(LIBS)

# This is the hycom utility includes (modules)
# NB: Path is relative to TMP dir
INCLUDE:= -I../ -I../../../include/ -I./ $(INCLUDE)

# Set specific flag SOUP is high resolution and frequency wind from oceanweather
#CPPFLAGS:=$(CPPFLAGS) -USOUP -DKARALIGHT
CPPFLAGS:=$(CPPFLAGS) 

# AIX (xlf) peculiarities. NB: Only necessary for Fortran files
ifneq (,$(findstring -DAIX,$(CPPFLAGS)))
   subs=-WF,-
   CPPFLAGS:=$(subst -,$(subs),$(CPPFLAGS))
endif

.F.o:
	cd Build/; $(CF90) -c $(INCLUDE) $(CPPFLAGS) $(FFLAGS) $(F77FLG) -o $*.o  ../$<

.F90.o:
	cd Build/; $(CF90) -c $(INCLUDE) $(CPPFLAGS) $(FFLAGS) $(F90FLG) -o $*.o  ../$<

.f.o:
	cd Build/; $(CF90) -c $(INCLUDE) $(FFLAGS) $(F77FLG) -o $*.o  ../$<



TARGET2=force_perturb-2.2

all:  $(TARGET2)

#################################################################################
#OBJECTS =\
#		  m_nearestpoint.o  \
#		  mod_year_info22.o \
#		  m_parse_blkdat.o \
#		  m_qsw0.o \
#		  m_ncvar_read.o  \
#		  m_interpug.o  \
#		  m_era40_fix.o  \
#		  mod_atm_func.o   \
#		  mod_forcing_nersc.o   \
#		  mod_clim_ocn.o   \
#		  mod_clim_atm.o   \
#		  m_ncvar_dims.o  \
#		  m_read_ecmwf_nc.o \
#		  m_read_ecmwf.o  \
#		  m_read_ncep.o \
#		  m_read_soup.o \
#		  mod_read_era40.o\
#		  mod_read_erai.o\
#		  mod_storm.o\
#		  p_forfun_nersc_new.o \
#		  dayfor.o
#
#$(TARGET): $(OBJECTS) 
#	cd Build/ ; $(LD) $(LINKFLAGS) -o ../$(TARGET) $(OBJECTS) $(LIBS)
#################################################################################
OBJECTS2= \
		  mod_year_info22.o \
		  m_parse_blkdat.o   \
		  mod_forcing_nersc.o   \
		  mod_pseudo.o \
		  mod_random_forcing.o   \
		  p_force_perturb.o \
		  dayfor.o
$(TARGET2): $(OBJECTS2) 
	cd Build/ ; $(LD) $(LINKFLAGS) -o ../$(TARGET2) $(OBJECTS2) $(LIBS)
#################################################################################

install : all
	mkdir -p ../../bin_setup/
	cp $(TARGET) $(TARGET2) ../../bin_setup/

clean:
	rm Build/*.o Build/*.mod  $(TARGET) $(TARGET3)

