use std::sync::atomic::{AtomicBool, Ordering};

#[cfg(target_os = "android")]
use std::sync::atomic::AtomicPtr;

static DSD_TRACK_ACTIVE: AtomicBool = AtomicBool::new(false);
static DSD_ENCODING_AVAILABLE: AtomicBool = AtomicBool::new(false);

#[cfg(target_os = "android")]
static DSD_TRACK_CLASS: AtomicPtr<std::ffi::c_void> = AtomicPtr::new(std::ptr::null_mut());

#[cfg(target_os = "android")]
const DSD_CLASS_NAME: &str = "com/mossapps/flick/DsdAudioTrackManager$Companion";

#[cfg(target_os = "android")]
fn get_cached_class() -> Option<*mut std::ffi::c_void> {
    let ptr = DSD_TRACK_CLASS.load(Ordering::Acquire);
    if ptr.is_null() { None } else { Some(ptr) }
}

#[cfg(target_os = "android")]
fn find_dsd_class<'env>(env: &mut jni::AttachGuard<'env>) -> Result<jni::objects::JClass<'env>, jni::errors::Error> {
    if let Some(ptr) = get_cached_class() {
        return Ok(unsafe { jni::objects::JClass::from_raw(ptr as jni::sys::jclass) });
    }

    match env.find_class(DSD_CLASS_NAME) {
        Ok(class) => {
            cache_class(env, &class);
            Ok(class)
        }
        Err(_) => {
            let _ = env.exception_clear();
            let ctx = ndk_context::android_context();
            let context = unsafe {
                jni::objects::JObject::from_raw(ctx.context() as jni::sys::jobject)
            };
            if context.is_null() {
                return Err(jni::errors::Error::NullPtr(
                    "No Android context available for classloader lookup",
                ));
            }
            let loader = env
                .call_method(&context, "getClassLoader", "()Ljava/lang/ClassLoader;", &[])?
                .l()?;
            let java_name = env.new_string(DSD_CLASS_NAME.replace('/', "."))?;
            let class_obj = env
                .call_method(
                    &loader,
                    "loadClass",
                    "(Ljava/lang/String;)Ljava/lang/Class;",
                    &[jni::objects::JValue::Object(&java_name)],
                )?
                .l()?;
            let class = unsafe { jni::objects::JClass::from_raw(class_obj.into_raw()) };
            cache_class(env, &class);
            Ok(class)
        }
    }
}

#[cfg(target_os = "android")]
fn cache_class(env: &mut jni::AttachGuard<'_>, class: &jni::objects::JClass<'_>) {
    if get_cached_class().is_some() {
        return;
    }
    match env.new_global_ref(class) {
        Ok(global_ref) => {
            let raw = global_ref.as_obj().as_raw() as *mut std::ffi::c_void;
            DSD_TRACK_CLASS.store(raw, Ordering::Release);
            std::mem::forget(global_ref);
            log::info!("[DSD-NATIVE] Cached DsdAudioTrackManager class reference");
        }
        Err(e) => {
            log::warn!("[DSD-NATIVE] Failed to cache class global ref: {}", e);
        }
    }
}

pub fn dsd_track_preload_class() {
    #[cfg(target_os = "android")]
    {
        if get_cached_class().is_some() {
            return;
        }
        let result = with_jni_env(|env| {
            let class = env.find_class(DSD_CLASS_NAME)?;
            cache_class(env, &class);
            Ok(())
        });
        if let Err(e) = result {
            log::warn!("[DSD-NATIVE] Preload class failed (will retry with classloader): {}", e);
        }
    }
}

pub fn dsd_track_class_available() -> bool {
    #[cfg(target_os = "android")]
    {
        let cached = DSD_ENCODING_AVAILABLE.load(Ordering::Acquire);
        if cached {
            return true;
        }
        let available = with_jni_env(|env| {
            let class = find_dsd_class(env)?;
            let result = env.call_static_method(
                &class,
                "isEncodingDsdAvailable",
                "()Z",
                &[],
            )?;
            Ok(result.z()?)
        })
        .unwrap_or_else(|e| {
            log::warn!("[DSD-NATIVE] ENCODING_DSD availability probe failed: {}", e);
            false
        });
        if available {
            DSD_ENCODING_AVAILABLE.store(true, Ordering::Release);
        }
        available
    }
    #[cfg(not(target_os = "android"))]
    {
        false
    }
}

pub fn set_dsd_encoding_available(available: bool) {
    DSD_ENCODING_AVAILABLE.store(available, Ordering::Release);
}

pub fn is_dsd_encoding_cached_available() -> bool {
    DSD_ENCODING_AVAILABLE.load(Ordering::Acquire)
}

pub fn dsd_track_create(sample_rate: u32, channels: usize) -> bool {
    #[cfg(target_os = "android")]
    {
        let result = with_jni_env(|env| {
            let class = find_dsd_class(env)?;
            let result = env.call_static_method(
                &class,
                "nativeCreate",
                "(II)Z",
                &[jni::objects::JValue::Int(sample_rate as i32), jni::objects::JValue::Int(channels as i32)],
            )?;
            let created = result.z()?;
            Ok(created)
        });
        match result {
            Ok(true) => {
                DSD_TRACK_ACTIVE.store(true, Ordering::Release);
                log::info!(
                    "[DSD-NATIVE] AudioTrack created: rate={} Hz, ch={}",
                    sample_rate, channels
                );
                true
            }
            Ok(false) => {
                log::warn!("[DSD-NATIVE] AudioTrack creation returned false");
                false
            }
            Err(e) => {
                log::error!("[DSD-NATIVE] AudioTrack create JNI error: {}", e);
                false
            }
        }
    }
    #[cfg(not(target_os = "android"))]
    {
        let _ = (sample_rate, channels);
        false
    }
}

pub fn dsd_track_play() -> bool {
    #[cfg(target_os = "android")]
    {
        with_jni_env(|env| {
            let class = find_dsd_class(env)?;
            let result = env.call_static_method(&class, "nativePlay", "()Z", &[])?;
            Ok(result.z()?)
        })
        .unwrap_or_else(|e| {
            log::error!("[DSD-NATIVE] AudioTrack play JNI error: {}", e);
            false
        })
    }
    #[cfg(not(target_os = "android"))]
    {
        false
    }
}

pub fn dsd_track_write(data: &[u8]) -> i32 {
    #[cfg(target_os = "android")]
    {
        with_jni_env(|env| {
            let byte_array = env.new_byte_array(data.len() as i32)?;
            unsafe {
                env.set_byte_array_region(
                    &byte_array,
                    0,
                    std::mem::transmute::<&[u8], &[i8]>(data),
                )?;
            }
            let class = find_dsd_class(env)?;
            let result = env.call_static_method(
                &class,
                "nativeWrite",
                "([B)I",
                &[jni::objects::JValue::Object(&byte_array.into())],
            )?;
            Ok(result.i()?)
        })
        .unwrap_or_else(|e| {
            log::error!("[DSD-NATIVE] AudioTrack write JNI error: {}", e);
            -1
        })
    }
    #[cfg(not(target_os = "android"))]
    {
        let _ = data;
        -1
    }
}

pub fn dsd_track_stop() {
    DSD_TRACK_ACTIVE.store(false, Ordering::Release);
    #[cfg(target_os = "android")]
    {
        let _ = with_jni_env(|env| {
            let class = find_dsd_class(env)?;
            env.call_static_method(&class, "nativeStop", "()V", &[])?;
            Ok(())
        });
    }
}

pub fn is_dsd_track_active() -> bool {
    DSD_TRACK_ACTIVE.load(Ordering::Acquire)
}

#[cfg(target_os = "android")]
fn with_jni_env<F, R>(f: F) -> Result<R, String>
where
    F: FnOnce(&mut jni::AttachGuard<'_>) -> Result<R, jni::errors::Error>,
{
    let ctx = ndk_context::android_context();
    let vm = unsafe { jni::JavaVM::from_raw(ctx.vm().cast()) }
        .map_err(|e| format!("Failed to get JavaVM: {}", e))?;
    let mut env = vm
        .attach_current_thread()
        .map_err(|e| format!("Failed to attach thread: {}", e))?;
    let result = f(&mut env);
    let _ = env.exception_clear();
    result.map_err(|e| format!("JNI call failed: {}", e))
}
