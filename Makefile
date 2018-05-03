#

all: Release Debug ReleaseMPI DebugMPI

MPIF90C ?= mpif90

# There are ___ kinds of F90 flags defined:
# F90COMMONFLAGS: These flags are specified for each kind (Debug, Release) of compilation
# F90DEBUGFLAGS: These flags are only used for creating Debug artefacts
# F90RELEASEFLAGS: These flags are only used for creating Release artefacts

# For standalone compiling set the compiler
ifneq ($(COMPILER),gfortran)
ifortErr = $(shell which ifort >/dev/null 2>&1; echo $$?)
else
ifortErr = 1
endif

ifeq "$(ifortErr)" "0"

ifortVer_major = $(shell ifort -v 2>&1 | cut -d " " -f 3 | cut -d. -f 1)
#Intel compiler
F90C     ?= ifort
F90DEBUGFLAGS ?= -g -traceback
F90RELEASEFLAGS ?= -fast
ifeq ($(shell test $(ifortVer_major) -gt 15; echo $$?),0)
F90COMMONFLAGS ?= -fpp -W0 -WB -fpic -qopenmp
else
F90COMMONFLAGS ?= -fpp -W0 -WB -fpic -openmp
endif
# Intel has a special archiver for libraries.
AREXE ?= xiar
ifneq "$(ifortVer_major)" "14"
# Check whether SRC_DIR is set to prevent adding gen-dep multiple times.
ifdef SRC_DIR
F90COMMONFLAGS += -gen-dep=$*.d
endif
endif

else

F90C ?= gfortran
F90COMMONFLAGS ?= -cpp -ffree-line-length-none -fmax-errors=4 -MMD -fopenmp -fPIC
F90DEBUGFLAGS ?= -g -O0
F90RELEASEFLAGS ?= -O3 -ffast-math

endif

# When no library archiver is set yet, use ar.
AREXE ?= ar

SRCS = MiscUtils.f90 StringUtils.f90 ArrayUtils.f90 MpiUtils.f90 FileUtils.f90 \
	   IniObjects.f90 RandUtils.f90 ObjectLists.f90 MatrixUtils.f90 RangeUtils.f90 \
	   Interpolation.f90

OBJS = $(patsubst %.f90,%.o,$(SRCS))

Release:
	$(MAKE) OUTPUT_DIR=Release F90FLAGS="$(F90RELEASEFLAGS)" directories

Releaselib:
	$(MAKE) OUTPUT_DIR=Releaselib directories

ReleaseMPI:
	$(MAKE) OUTPUT_DIR=ReleaseMPI F90C=$(MPIF90C) F90FLAGS="$(F90RELEASEFLAGS) -DMPI" directories

Debug:
	$(MAKE) OUTPUT_DIR=Debug F90FLAGS="$(F90DEBUGFLAGS)" directories

Debuglib:
	$(MAKE) OUTPUT_DIR=Debuglib directories

DebugMPI:
	$(MAKE) OUTPUT_DIR=DebugMPI F90C=$(MPIF90C) F90FLAGS="$(F90DEBUGFLAGS) -DMPI" directories

%.o: $(SRC_DIR)/%.f90
	$(F90C) $(F90COMMONFLAGS) $(F90FLAGS) -o $*.o -c $<

libforutils.a: $(OBJS)
	$(AREXE) -r libforutils.a $(OBJS)

clean:
	-rm -fr Debug* Release*

# export all variables to the sub-make below
export

# Build in output dir to get file dependencies correctly and make use
# of delta builds, where only changed files and their dependents are
# rebuild.
directories:
	mkdir -p $(OUTPUT_DIR)
	$(MAKE) -C $(OUTPUT_DIR) -f../Makefile SRC_DIR=.. libforutils.a

# Include dependency files generated by a previous run of make
-include $(SRCS:.f90=.d)

.PHONY: directories clean Release Debug ReleaseMPI DebugMPI libforutils.a

#Avoid problems with intel gen-dep
mpif.h:
	echo ''
