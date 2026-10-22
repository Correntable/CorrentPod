package com.adeeteya.classipod





import android.os.Build


import android.os.Bundle


import android.view.WindowManager


import io.flutter.embedding.android.FlutterActivity





class MainActivity : FlutterActivity() {


    override fun onCreate(savedInstanceState: Bundle?) {


        super.onCreate(savedInstanceState)


        if (Build.VERSION.SDK_INT >= 27) {


            setShowWhenLocked(true)


            setTurnScreenOn(true)


        } else {


            @Suppress("DEPRECATION")


            window.addFlags(


                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or


                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON


            )


        }


    }


}
