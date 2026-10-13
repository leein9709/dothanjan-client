package org.dothanjan.session

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import android.util.Base64
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.UsedByGodot
import org.json.JSONObject
import java.io.File
import java.io.FileNotFoundException
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class SessionStorePlugin(godot: Godot) : GodotPlugin(godot) {
    override fun getPluginName() = "SessionStore"
    private val alias = "dothanjan.mobile.session.v1"
    private val aad = alias.toByteArray(Charsets.UTF_8)
    private fun file(): AtomicFile {
        val context = activity?.applicationContext ?: throw IllegalStateException()
        // This directory is excluded from Android backup and device-transfer backups.
        val folder = File(context.noBackupFilesDir, "dothanjan-auth")
        if (!folder.exists() && !folder.mkdirs()) throw IllegalStateException()
        return AtomicFile(File(folder, "session.enc"))
    }
    private fun key(create: Boolean): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(alias, null) as? SecretKey)?.let { return it }
        if (!create) throw IllegalStateException()
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256).setRandomizedEncryptionRequired(true).build())
        }.generateKey()
    }

    @Synchronized @UsedByGodot
    fun load_credentials(): String = try {
        val storage = file()
        val bytes = try { storage.readFully() } catch (_: FileNotFoundException) { null }
        if (bytes == null) "" else {
            if (bytes.size > 16384) throw IllegalStateException()
            val envelope = JSONObject(bytes.toString(Charsets.UTF_8))
            if (envelope.getInt("v") != 1) throw IllegalStateException()
            val iv = Base64.decode(envelope.getString("iv"), Base64.NO_WRAP)
            if (iv.size != 12) throw IllegalStateException()
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key(false), GCMParameterSpec(128, iv))
            cipher.updateAAD(aad)
            cipher.doFinal(Base64.decode(envelope.getString("data"), Base64.NO_WRAP)).toString(Charsets.UTF_8)
        }
    } catch (_: Exception) { "!storage_error" }

    @Synchronized @UsedByGodot
    fun save_credentials(payload: String): Boolean = try {
        val plain = payload.toByteArray(Charsets.UTF_8)
        if (plain.size > 8192) throw IllegalStateException()
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key(true))
        cipher.updateAAD(aad)
        val envelope = JSONObject().put("v", 1)
            .put("iv", Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
            .put("data", Base64.encodeToString(cipher.doFinal(plain), Base64.NO_WRAP)).toString()
        val storage = file()
        val stream = storage.startWrite()
        try { stream.write(envelope.toByteArray(Charsets.UTF_8)); storage.finishWrite(stream) }
        catch (error: Exception) { storage.failWrite(stream); throw error }
        true
    } catch (_: Exception) { false }

    @Synchronized @UsedByGodot
    fun clear_credentials(): Boolean = try {
        val storage = file()
        storage.delete()
        !storage.baseFile.exists() && !File(storage.baseFile.path + ".bak").exists()
            && !File(storage.baseFile.path + ".new").exists()
    } catch (_: Exception) { false }
}
