LOCAL_PATH := $(call my-dir)
ifeq ($(QUEST_XR),1)
include $(CLEAR_VARS)
LOCAL_MODULE := questxr
LOCAL_SRC_FILES := questxr_bridge.c
LOCAL_CFLAGS := -std=c11 -DGL_GLEXT_PROTOTYPES -fvisibility=hidden
# Generated from the pinned public Khronos Maven AAR by prepareQuestOpenXRHeaders.
ifeq ($(strip $(QUEST_OPENXR_INCLUDE)),)
$(error QUEST_OPENXR_INCLUDE must name the public OpenXR headers directory)
endif
LOCAL_C_INCLUDES := $(QUEST_OPENXR_INCLUDE)
LOCAL_LDLIBS := -llog -landroid -lz -ldl -lm -lEGL -lGLESv3
include $(BUILD_SHARED_LIBRARY)
endif
