"""Se ejecuta en GitHub Actions despues de `flutter create`: añade permisos y minSdk."""
import glob, re, sys

# 1) Permisos y nombre de la app
mf = 'android/app/src/main/AndroidManifest.xml'
s = open(mf, encoding='utf-8').read()
perms = '''    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28"/>
    <uses-feature android:name="android.hardware.camera" android:required="false"/>
'''
if 'android.permission.CAMERA' not in s:
    s = s.replace('<application', perms + '    <application', 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="Ancla"', s, count=1)
open(mf, 'w', encoding='utf-8').write(s)

# 2) minSdk 24 (el plugin de audio exige >= 23)
done = False
for g in glob.glob('android/app/build.gradle*'):
    t = open(g, encoding='utf-8').read()
    n = re.sub(r'minSdk(Version)?\s*=?\s*flutter\.minSdkVersion', 'minSdk = 24', t)
    if n != t:
        open(g, 'w', encoding='utf-8').write(n); done = True
if not done:
    print('AVISO: no se encontro minSdk para cambiar', file=sys.stderr); sys.exit(1)
print('Android parcheado OK')
