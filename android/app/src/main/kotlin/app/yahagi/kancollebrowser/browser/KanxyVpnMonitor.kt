package app.yahagi.kancollebrowser.browser

import android.content.Context
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.MainThread

private val kanxyPackages = listOf("com.axis000.kanxy", "com.kanxy.android")

internal fun hasEnabledKanxyPackage(isPackageEnabled: (String) -> Boolean): Boolean =
    kanxyPackages.any(isPackageEnabled)

@Suppress("DEPRECATION")
internal fun PackageManager.hasEnabledKanxy(): Boolean = hasEnabledKanxyPackage { packageName ->
    try {
        getApplicationInfo(packageName, 0).enabled
    } catch (_: PackageManager.NameNotFoundException) {
        false
    }
}

internal class KanxyVpnMonitor(context: Context, private val onChanged: (Boolean) -> Unit) {
    private val appContext = context.applicationContext
    private val connectivity = appContext.getSystemService(ConnectivityManager::class.java)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var running = false
    private var callback: ConnectivityManager.NetworkCallback? = null
    private var sampled = false
    private var observedNetwork: Network? = null
    private var pendingLoss: Runnable? = null

    @Volatile
    private var activeState = false

    val active: Boolean get() = activeState

    @MainThread
    fun start() {
        if (running) return
        running = true
        if (connectivity != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val listener = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) = scheduleRefresh()
                override fun onLost(network: Network) = scheduleRefresh()

                override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) =
                    scheduleRefresh()

                override fun onLinkPropertiesChanged(network: Network, linkProperties: LinkProperties) =
                    scheduleRefresh()

                private fun scheduleRefresh() {
                    // Recheck the current default outside the connectivity callback thread.
                    mainHandler.post {
                        if (callback === this) refresh()
                    }
                }
            }
            try {
                connectivity.registerDefaultNetworkCallback(listener)
                callback = listener
            } catch (error: RuntimeException) {
                Log.w(TAG, "Unable to monitor default network changes", error)
            }
        }
        refresh()
    }

    @MainThread
    fun refresh() = sample(deferLoss = true)

    private fun sample(deferLoss: Boolean) {
        if (!running) return
        val detected = try {
            kanxyDefaultNetwork()
        } catch (error: SecurityException) {
            Log.w(TAG, "Unable to inspect the default network", error)
            null
        }
        // Default-network callbacks can briefly lose the VPN during a handoff.
        if (activeState && detected == null && deferLoss) {
            if (pendingLoss == null) {
                val check = Runnable {
                    pendingLoss = null
                    sample(deferLoss = false)
                }
                pendingLoss = check
                mainHandler.postDelayed(check, LOSS_CONFIRMATION_MILLIS)
            }
            return
        }
        pendingLoss?.let(mainHandler::removeCallbacks)
        pendingLoss = null
        if (!sampled || observedNetwork != detected) {
            sampled = true
            observedNetwork = detected
            activeState = detected != null
            onChanged(activeState)
        }
    }

    @MainThread
    fun stop() {
        running = false
        val listener = callback
        callback = null
        pendingLoss?.let(mainHandler::removeCallbacks)
        pendingLoss = null
        sampled = false
        observedNetwork = null
        activeState = false
        if (listener != null) {
            runCatching { connectivity?.unregisterNetworkCallback(listener) }
        }
    }

    private fun kanxyDefaultNetwork(): Network? {
        val manager = connectivity ?: return null
        val network = manager.activeNetwork ?: return null
        if (manager.getNetworkCapabilities(network)?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) != true) {
            return null
        }
        val link = manager.getLinkProperties(network) ?: return null
        return network.takeIf { link.linkAddresses.any { it.prefixLength == 24 && it.address.hostAddress == TUN_ADDRESS } &&
            link.dnsServers.any { it.hostAddress == TUN_DNS } &&
            appContext.packageManager.hasEnabledKanxy() && manager.activeNetwork == network }
    }

    private companion object {
        const val TAG = "KanxyVpnMonitor"
        const val LOSS_CONFIRMATION_MILLIS = 800L
        // Addresses set by Kanxy 0.2.0's VpnService.
        const val TUN_ADDRESS = "10.251.0.2"
        const val TUN_DNS = "10.251.0.1"
    }
}
