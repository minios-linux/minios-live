pkgname=dracut-git
pkgver=1
pkgrel=1
pkgdesc="Initramfs generation utility"
arch=('i686' 'x86_64')
url="https://dracut.wiki.kernel.org/"
license=('GPL')
conflicts=('dracut' 'mkinitcpio')
provides=('dracut=9999' 'mkinitcpio=9999')
depends=('bash')
optdepends=('cryptsetup' 'lvm2')
makedepends=('libxslt')
backup=(etc/dracut.conf)
source=()
md5sums=()

# out of tree builds disallowed for this PKGFILE
BUILDDIR="${PWD}"
PKGDEST="${PWD}"
SRCDEST=""
SRCPKGDEST=""
LOGDEST=""

pkgver() {
  cd ..
  desc="$(git describe)"
  printf "%s.%s.%s" ${desc//-/ }
}

build() {
  cd ..
  make sysconfdir=/etc || return 1
}

package() {
  cd ..
  make DESTDIR="${pkgdir}" sysconfdir=/etc install || return 1
}
