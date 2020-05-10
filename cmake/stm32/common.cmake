set(STM32_SUPPORTED_FAMILIES L0 L1 L4 F0 F1 F2 F3 F4 F7 H7)

if(NOT STM32_TOOLCHAIN_PATH)
     set(STM32_TOOLCHAIN_PATH "/usr")
     message(STATUS "No STM32_TOOLCHAIN_PATH specified, using default: " ${STM32_TOOLCHAIN_PATH})
else()
     file(TO_CMAKE_PATH "${STM32_TOOLCHAIN_PATH}" STM32_TOOLCHAIN_PATH)
endif()

if(NOT STM32_TARGET_TRIPLET)
    set(STM32_TARGET_TRIPLET "arm-none-eabi")
    message(STATUS "No STM32_TARGET_TRIPLET specified, using default: " ${STM32_TARGET_TRIPLET})
endif()

set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR arm)

set(TOOLCHAIN_SYSROOT  "${STM32_TOOLCHAIN_PATH}/${STM32_TARGET_TRIPLET}")
set(TOOLCHAIN_BIN_PATH "${STM32_TOOLCHAIN_PATH}/bin")
set(TOOLCHAIN_INC_PATH "${STM32_TOOLCHAIN_PATH}/${STM32_TARGET_TRIPLET}/include")
set(TOOLCHAIN_LIB_PATH "${STM32_TOOLCHAIN_PATH}/${STM32_TARGET_TRIPLET}/lib")

find_program(CMAKE_OBJCOPY NAMES ${STM32_TARGET_TRIPLET}-objcopy PATHS ${TOOLCHAIN_BIN_PATH})
find_program(CMAKE_OBJDUMP NAMES ${STM32_TARGET_TRIPLET}-objdump PATHS ${TOOLCHAIN_BIN_PATH})
find_program(CMAKE_SIZE NAMES ${STM32_TARGET_TRIPLET}-size PATHS ${TOOLCHAIN_BIN_PATH})
find_program(CMAKE_DEBUGGER NAMES ${STM32_TARGET_TRIPLET}-gdb PATHS ${TOOLCHAIN_BIN_PATH})
find_program(CMAKE_CPPFILT NAMES ${STM32_TARGET_TRIPLET}-c++filt PATHS ${TOOLCHAIN_BIN_PATH})

function(stm32_get_chip_type FAMILY DEVICE TYPE)
    set(INDEX 0)
    foreach(C_TYPE ${STM32_${FAMILY}_TYPES})
        list(GET STM32_${FAMILY}_TYPE_MATCH ${INDEX} REGEXP)
        if(${DEVICE} MATCHES ${REGEXP})
            set(RESULT_TYPE ${C_TYPE})
        endif()
        math(EXPR INDEX "${INDEX}+1")
    endforeach()
    if(NOT RESULT_TYPE)
        message(FATAL_ERROR "Invalid/unsupported device: ${DEVICE}")
    endif()
    set(${TYPE} ${RESULT_TYPE} PARENT_SCOPE)
endfunction()

function(stm32_get_chip_info CHIP FAMILY TYPE DEVICE)
    string(TOUPPER ${CHIP} CHIP)
        
    string(REGEX MATCH "^STM32([A-Z][0-9])([0-9][0-9][A-Z][0-9A-Z]).*$" CHIP ${CHIP})
    
    if((NOT CMAKE_MATCH_1) OR (NOT CMAKE_MATCH_2))
        message(FATAL_ERROR "Unknown chip ${CHIP}")
    endif()
    
    set(STM32_FAMILY ${CMAKE_MATCH_1})
    set(STM32_DEVICE "${CMAKE_MATCH_1}${CMAKE_MATCH_2}")
    
    list(FIND STM32_SUPPORTED_FAMILIES ${STM32_FAMILY} STM32_FAMILY_INDEX)
    if (STM32_FAMILY_INDEX EQUAL -1)
        message(FATAL_ERROR "Unsupported family ${STM32_FAMILY} for device ${CHIP}")
    endif()

    stm32_get_chip_type(${STM32_FAMILY} ${STM32_DEVICE} STM32_TYPE)
    
    set(${FAMILY} ${STM32_FAMILY} PARENT_SCOPE)
    set(${DEVICE} ${STM32_DEVICE} PARENT_SCOPE)
    set(${TYPE} ${STM32_TYPE} PARENT_SCOPE)
endfunction()

function(stm32_get_memory_info FAMILY DEVICE 
    FLASH_SIZE RAM_SIZE CCRAM_SIZE STACK_SIZE HEAP_SIZE 
    FLASH_ORIGIN RAM_ORIGIN CCRAM_ORIGIN
)
    string(REGEX REPLACE "^[FGHL][0-9][0-9][0-9].([3468BCDEFGHIZ])$" "\\1" SIZE_CODE ${DEVICE})
    
    if(SIZE_CODE STREQUAL "3")
        set(FLASH "8K")
    elseif(SIZE_CODE STREQUAL "4")
        set(FLASH "16K")
    elseif(SIZE_CODE STREQUAL "6")
        set(FLASH "32K")
    elseif(SIZE_CODE STREQUAL "8")
        set(FLASH "64K")
    elseif(SIZE_CODE STREQUAL "B")
        set(FLASH "128K")
    elseif(SIZE_CODE STREQUAL "C")
        set(FLASH "256K")
    elseif(SIZE_CODE STREQUAL "D")
        set(FLASH "384K")
    elseif(SIZE_CODE STREQUAL "E")
        set(FLASH "512K")
    elseif(SIZE_CODE STREQUAL "F")
        set(FLASH "768K")
    elseif(SIZE_CODE STREQUAL "G")
        set(FLASH "1024K")
    elseif(SIZE_CODE STREQUAL "H")
        set(FLASH "1536K")
    elseif(SIZE_CODE STREQUAL "I")
        set(FLASH "2048K")
    elseif(SIZE_CODE STREQUAL "Z")
        set(FLASH "192K")
    else()
        set(FLASH "16K")
        message(WARNING "Unknow flash size for device ${DEVICE}")
    endif()
    
    stm32_get_chip_type(${FAMILY} ${DEVICE} TYPE)
    list(FIND STM32_${FAMILY}_TYPES ${TYPE} TYPE_INDEX)
    list(GET STM32_${FAMILY}_RAM_SIZES ${TYPE_INDEX} RAM)
    list(GET STM32_${FAMILY}_CCRAM_SIZES ${TYPE_INDEX} CCRAM)
    
    if(FAMILY STREQUAL "F1")
        stm32f1_get_memory_info(${DEVICE} ${TYPE} FLASH RAM)
    elseif(FAMILY STREQUAL "L1")
        stm32l1_get_memory_info(${DEVICE} ${TYPE} FLASH RAM)
    elseif(FAMILY STREQUAL "F2")
        stm32f2_get_memory_info(${DEVICE} ${TYPE} FLASH RAM)
    elseif(FAMILY STREQUAL "F3")
        stm32f3_get_memory_info(${DEVICE} ${TYPE} FLASH RAM)
    endif()

    set(${FLASH_SIZE} ${FLASH} PARENT_SCOPE)
    set(${RAM_SIZE} ${RAM} PARENT_SCOPE)
    set(${CCRAM_SIZE} ${CCRAM} PARENT_SCOPE)
    if (RAM STREQUAL "2K")
        # Potato MCUs
        set(${STACK_SIZE} 0x200 PARENT_SCOPE)
        set(${HEAP_SIZE} 0x100 PARENT_SCOPE)
    else()
        set(${STACK_SIZE} 0x400 PARENT_SCOPE)
        set(${HEAP_SIZE} 0x200 PARENT_SCOPE)
    endif()
    set(${FLASH_ORIGIN} 0x8000000 PARENT_SCOPE)
    set(${RAM_ORIGIN} 0x20000000 PARENT_SCOPE)
    set(${CCRAM_ORIGIN} 0x10000000 PARENT_SCOPE)
endfunction()

function(stm32_add_linker_script TARGET VISIBILITY SCRIPT)
    get_filename_component(SCRIPT "${SCRIPT}" ABSOLUTE)
    target_link_options(${TARGET} ${VISIBILITY} -T "${SCRIPT}")
endfunction()

if(NOT (TARGET STM32::NoSys))
    add_library(STM32::NoSys INTERFACE IMPORTED)
    target_compile_options(STM32::NoSys INTERFACE $<$<C_COMPILER_ID:GNU>:--specs=nosys.specs>)
    target_link_options(STM32::NoSys INTERFACE $<$<C_COMPILER_ID:GNU>:--specs=nosys.specs>)
endif()

include(stm32/utilities)
include(stm32/f0)
include(stm32/g0)
include(stm32/l0)
include(stm32/f1)
include(stm32/l1)
include(stm32/f2)
include(stm32/f3)
include(stm32/f4)

