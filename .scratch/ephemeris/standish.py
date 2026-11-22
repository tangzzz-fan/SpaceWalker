"""Standish (JPL Approximate Positions of the Planets) 1800-2050 根数原型验证。"""
import math

# a, e, I, L, long.peri, long.node + rates per century
ELEMENTS = {
 'mercury': [0.38709927,0.20563593,7.00497902,252.25032350,77.45779628,48.33076593,
             0.00000037,0.00001906,-0.00594749,149472.67411175,0.16047689,-0.12534081],
 'venus':   [0.72333566,0.00677672,3.39467605,181.97909950,131.60246718,76.67984255,
             0.00000390,-0.00004107,-0.00078890,58517.81538729,0.00268329,-0.27769418],
 'emb':     [1.00000261,0.01671123,-0.00001531,100.46457166,102.93768193,0.0,
             0.00000562,-0.00004392,-0.01294668,35999.37244981,0.32327364,0.0],
 'mars':    [1.52371034,0.09339410,1.84969142,-4.55343205,-23.94362959,49.55953891,
             0.00001847,0.00007882,-0.00813131,19140.30268499,0.44441088,-0.29257343],
 'jupiter': [5.20288700,0.04838624,1.30439695,34.39644051,14.72847983,100.47390909,
             -0.00011607,-0.00013253,-0.00183714,3034.74612775,0.21252668,0.20469106],
 'saturn':  [9.53667594,0.05386179,2.48599187,49.95424423,92.59887831,113.66242448,
             -0.00125060,-0.00050991,0.00193609,1222.49362201,-0.41897216,-0.28867794],
 'uranus':  [19.18916464,0.04725744,0.77263783,313.23810451,170.95427630,74.01692503,
             -0.00196176,-0.00004397,-0.00242939,428.48202785,0.40805281,0.04240589],
 'neptune': [30.06992276,0.00859048,1.77004347,-55.12002969,44.96476227,131.78422574,
             0.00026291,0.00005105,0.00035372,218.45945325,-0.32241464,-0.00508664],
}
D2R = math.pi/180

def helio(name, jd):
    T = (jd - 2451545.0)/36525.0
    el = ELEMENTS[name]
    a = el[0]+el[6]*T; e = el[1]+el[7]*T; I = (el[2]+el[8]*T)*D2R
    L = el[3]+el[9]*T; wbar = el[4]+el[10]*T; Om = (el[5]+el[11]*T)*D2R
    w = wbar*D2R - Om
    M = (L - wbar) % 360
    M = (M + 180) % 360 - 180
    Mr = M*D2R
    E = Mr + e*math.sin(Mr)
    for _ in range(50):
        dM = M - (E/D2R - e/D2R*math.sin(E))
        dE = dM*D2R/(1-e*math.cos(E))
        E += dE
        if abs(dE) < 1e-9: break
    xp = a*(math.cos(E)-e)
    yp = a*math.sqrt(1-e*e)*math.sin(E)
    cw,sw = math.cos(w),math.sin(w)
    cO,sO = math.cos(Om),math.sin(Om)
    ci,si = math.cos(I),math.sin(I)
    x = (cw*cO-sw*sO*ci)*xp + (-sw*cO-cw*sO*ci)*yp
    y = (cw*sO+sw*cO*ci)*xp + (-sw*sO+cw*cO*ci)*yp
    z = (sw*si)*xp + (cw*si)*yp
    return x,y,z

def geocentric_ecliptic(name, jd):
    if name=='sun':
        ex,ey,ez = helio('emb',jd)
        return -ex,-ey,-ez
    x,y,z = helio(name,jd)
    ex,ey,ez = helio('emb',jd)
    return x-ex,y-ey,z-ez

def radec(name, jd):
    x,y,z = geocentric_ecliptic(name,jd)
    eps = 23.43928*D2R
    xe = x
    ye = y*math.cos(eps)-z*math.sin(eps)
    ze = y*math.sin(eps)+z*math.cos(eps)
    ra = math.atan2(ye,xe)/D2R % 360
    dec = math.atan2(ze,math.hypot(xe,ye))/D2R
    return ra,dec

def moon_radec(jd):
    """Meeus Astronomical Algorithms ch.47 低精度（截断主项）。"""
    T = (jd-2451545.0)/36525.0
    Lp = 218.3164477 + 481267.88123421*T - 0.0015786*T*T
    D  = 297.8501921 + 445267.1114034*T - 0.0018819*T*T
    M  = 357.5291092 + 35999.0502909*T - 0.0001536*T*T
    Mp = 134.9633964 + 477198.8675055*T + 0.0087414*T*T
    F  = 93.2720950 + 483202.0175233*T - 0.0036539*T*T
    A1 = 119.75 + 131.849*T
    A2 = 53.09 + 479264.290*T
    A3 = 313.45 + 481266.484*T
    E = 1 - 0.002516*T - 0.0000074*T*T
    args = [D,M,Mp,F]
    def s(coeff):
        # coeff: (d,m,mp,f, lon(1e-6 deg), lat(1e-6 deg))
        total=0.0
        for d,m,mp,f,cl,cb in coeff:
            a = (d*D+m*M+mp*Mp+f*F)*D2R
            e = abs(m)
            ef = E**e
            total += (cl if coeff is LON else cb)*ef*math.sin(a)
        return total
    LON = [
      (0,0,1,0,6288774,0),(2,0,-1,0,1274027,0),(2,0,0,0,658314,0),(0,0,2,0,213618,0),
      (0,1,0,0,-185116,0),(0,0,0,2,-114332,0),(2,0,-2,0,58793,0),(2,-1,-1,0,57066,0),
      (2,0,1,0,53322,0),(2,-1,0,0,45758,0),(0,1,-1,0,-40923,0),(1,0,0,0,-34720,0),
      (0,1,1,0,-30383,0),(2,0,0,-2,15327,0),(0,0,1,2,-12528,0),(0,0,1,-2,10980,0),
      (4,0,-1,0,10675,0),(0,0,3,0,10034,0),(4,0,-2,0,8548,0),(2,1,-1,0,-7888,0),
      (2,1,0,0,-6766,0),(1,0,-1,0,-5163,0),(1,1,0,0,4987,0),(2,-1,1,0,4036,0),
      (2,0,2,0,3994,0),(4,0,0,0,3861,0),(2,0,-3,0,3665,0),(0,1,-2,0,-2689,0),
      (2,0,-1,2,-2602,0),(2,-1,-2,0,2390,0),(1,0,1,0,-2348,0),(2,-2,0,0,2236,0),
      (0,1,2,0,-2120,0),(0,2,0,0,-2069,0),(2,-2,-1,0,2048,0),(2,0,1,-2,-1773,0),
      (2,0,0,2,-1595,0),(4,-1,-1,0,1215,0),(0,0,2,2,-1110,0),(3,0,-1,0,-892,0),
      (2,1,1,0,-810,0),(4,-1,-2,0,759,0),(0,2,-1,0,-713,0),(2,2,-1,0,-700,0),
      (2,1,-2,0,691,0),(2,-1,0,-2,596,0),(4,0,1,0,549,0),(0,0,4,0,537,0),
      (4,-1,0,0,520,0),(1,0,-2,0,-487,0),(2,-1,2,0,-399,0),(2,0,2,-2,-381,0),
      (1,1,1,0,351,0),(3,0,-2,0,-340,0),(4,0,-3,0,330,0),(2,-1,1,2,327,0),
      (0,2,1,0,-323,0),(1,1,-1,0,299,0),(2,0,3,0,294,0),(2,0,-1,-2,0,0)]
    LAT = [
      (0,0,0,1,5128122,0),(0,0,1,1,280602,0),(0,0,1,-1,277693,0),(2,0,0,-1,173237,0),
      (2,0,-1,1,55413,0),(2,0,-1,-1,46271,0),(2,0,0,1,32573,0),(0,0,2,1,17198,0),
      (2,0,1,-1,9266,0),(0,0,2,-1,8822,0),(2,-1,0,-1,8216,0),(2,0,-2,-1,4324,0),
      (2,0,1,1,4200,0),(2,1,0,-1,-3359,0),(2,-1,-1,1,2463,0),(2,-1,0,1,2211,0),
      (2,-1,-1,-1,2065,0),(0,1,-1,-1,-1870,0),(4,0,-1,-1,1828,0),(0,1,0,1,-1794,0),
      (0,0,0,3,-1749,0),(0,1,-1,1,-1565,0),(1,0,0,1,-1491,0),(0,1,1,1,-1475,0),
      (0,1,1,-1,-1410,0),(0,1,0,-1,-1344,0),(1,0,0,-1,-1335,0),(0,0,3,1,1107,0),
      (4,0,0,-1,1021,0),(4,0,-1,1,833,0)]
    def term(coeff):
        total=0.0
        for d,m,mp,f,c in coeff:
            a=(d*D+m*M+mp*Mp+f*F)*D2R
            ef=E**abs(m)
            total+=c*ef*math.sin(a)
        return total
    lon = Lp + (term([(d,m,mp,f,cl) for d,m,mp,f,cl,_ in LON])
        + 3958*math.sin(A1*D2R) + 1962*math.sin((Lp-F)*D2R) + 318*math.sin(A2*D2R))/1e6
    lat = (term([(d,m,mp,f,cl) for d,m,mp,f,cl,_ in LAT])
        - 2235*math.sin(Lp*D2R) + 382*math.sin(A3*D2R)
        + 175*math.sin((A1-F)*D2R) + 175*math.sin((A1+F)*D2R)
        + 127*math.sin((Lp-Mp)*D2R) - 115*math.sin((Lp+Mp)*D2R))/1e6
    lon%=360
    # 黄经黄纬是「当日平春分点」，先转当日赤道，再岁差回 J2000（ICRF 近似）
    eps=(23.439291-0.0130042*T)*D2R
    l,b=lon*D2R,lat*D2R
    x=math.cos(b)*math.cos(l); y=math.cos(b)*math.sin(l); z=math.sin(b)
    ye=y*math.cos(eps)-z*math.sin(eps); ze=y*math.sin(eps)+z*math.cos(eps)
    ra_d=math.atan2(ye,x); dec_d=math.atan2(ze,math.hypot(x,ye))
    xd=math.cos(dec_d)*math.cos(ra_d); yd=math.cos(dec_d)*math.sin(ra_d); zd=math.sin(dec_d)
    arcsec=D2R/3600
    zeta=(2306.2181*T+0.30188*T*T+0.017998*T**3)*arcsec
    zz  =(2306.2181*T+1.09468*T*T+0.018203*T**3)*arcsec
    theta=(2004.3109*T-0.42665*T*T-0.041833*T**3)*arcsec
    # J2000->date 矩阵的转置即逆变换
    cz,sz=math.cos(zeta),math.sin(zeta)
    cZ,sZ=math.cos(zz),math.sin(zz)
    ct,st=math.cos(theta),math.sin(theta)
    # forward rows (Meeus 21.4):
    r1=(cz*cZ*ct-sz*sZ, -sz*cZ*ct-cz*sZ, -cZ*st)
    r2=(cz*sZ*ct+sz*cZ, -sz*sZ*ct+cz*cZ, -sZ*st)
    r3=(cz*st, -sz*st, ct)
    x0=r1[0]*xd+r2[0]*yd+r3[0]*zd
    y0=r1[1]*xd+r2[1]*yd+r3[1]*zd
    z0=r1[2]*xd+r2[2]*yd+r3[2]*zd
    ra=math.atan2(y0,x0)/D2R%360
    dec=math.atan2(z0,math.hypot(x0,y0))/D2R
    return ra,dec

if __name__=='__main__':
    import glob,re,sys
    worst={}
    for path in sorted(glob.glob('/tmp/hyg/horizons/raw_*.txt')):
        m=re.match(r'raw_(\d+)_(\d{4}-\d{2}-\d{2})',path.split('/')[-1])
        cmd,d=m.group(1),m.group(2)
        txt=open(path).read()
        soe=txt.find('$$SOE'); eoe=txt.find('$$EOE')
        if soe<0: print('NO DATA',path); continue
        line=txt[soe+5:eoe].strip().split('\n')[0]
        parts=[p.strip() for p in line.split(',')]
        jd=float(parts[0]); ra_ref=float(parts[3]); dec_ref=float(parts[4])
        names={'199':'mercury','299':'venus','499':'mars','599':'jupiter','699':'saturn','799':'uranus','899':'neptune','10':'sun','301':'moon'}
        name=names[cmd]
        ra,dec = moon_radec(jd) if name=='moon' else radec(name,jd)
        dra=(ra-ra_ref+180)%360-180
        sep=math.hypot(dra*math.cos(math.radians(dec_ref)),dec-dec_ref)*60
        key=name
        worst[key]=max(worst.get(key,0),sep)
        if sep> (20 if name=='moon' else 10):
            print(f'FAIL {name} {d}: {sep:.1f} arcmin (ra {ra:.4f} vs {ra_ref}, dec {dec:.4f} vs {dec_ref})')
    print('worst per body (arcmin):')
    for k,v in sorted(worst.items()): print(f'  {k}: {v:.2f}')
