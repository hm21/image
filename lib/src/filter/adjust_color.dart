import 'dart:math';

import '../color/channel.dart';
import '../color/color.dart';
import '../image/image.dart';
import '../util/color_util.dart';
import '../util/math_util.dart';

/// Adjust the color of the [src] image using various color transformations.
///
/// [blacks] defines the black level of the image, as a color.
///
/// [whites] defines the white level of the image, as a color.
///
/// [mids] defines the mid level of the image, as a color.
///
/// [contrast] increases (> 1) / decreases (< 1) the contrast of the image by
/// pushing colors away/toward neutral gray, where at 0.0 the image is entirely
/// neutral gray (0 contrast), 1.0, the image is not adjusted and > 1.0 the
/// image increases contrast.
///
/// [saturation] increases (> 1) / decreases (< 1) the saturation of the image
/// by pushing colors away/toward their grayscale value, where 0.0 is grayscale
/// and 1.0 is the original image, and > 1.0 the image becomes more saturated.
///
/// [brightness] is a constant scalar of the image colors. At 0 the image
/// is black, 1.0 unmodified, and > 1.0 the image becomes brighter.
///
/// [gamma] is an exponential scalar of the image colors. At < 1.0 the image
/// becomes brighter, and > 1.0 the image becomes darker. A [gamma] of 1/2.2
/// will convert the image colors to linear color space.
///
/// [exposure] is an exponential scalar of the image as rgb/// pow(2, exposure).
/// At 0, the image is unmodified; as the exposure increases, the image
/// brightens.
///
/// [hue] shifts the hue component of the image colors in degrees. A [hue] of
/// 0 will have no affect, and a [hue] of 45 will shift the hue of all colors
/// by 45 degrees.
///
/// [amount] controls how much affect this filter has on the [src] image, where
/// 0.0 has no effect and 1.0 has full effect.
///
Image adjustColor(Image src,
    {Color? blacks,
    Color? whites,
    Color? mids,
    num? contrast,
    num? saturation,
    num? brightness,
    num? gamma,
    num? exposure,
    num? hue,
    num amount = 1,
    Image? mask,
    Channel maskChannel = Channel.luminance}) {
  if (amount == 0) {
    return src;
  }

  if (src.hasPalette) {
    src = src.convert(numChannels: src.numChannels);
  }

  contrast = contrast?.clamp(0, 2);
  gamma = gamma?.clamp(0, 1000);
  exposure = exposure?.clamp(0, 1000);
  amount = amount.clamp(0, 1000);

  const avgLumR = 0.5;
  const avgLumG = 0.5;
  const avgLumB = 0.5;

  final useBlacksWhitesMids = blacks != null || whites != null || mids != null;
  late num br, bg, bb;
  late num wr, wg, wb;
  late num mr, mg, mb;
  if (useBlacksWhitesMids) {
    br = blacks?.rNormalized ?? 0;
    bg = blacks?.gNormalized ?? 0;
    bb = blacks?.bNormalized ?? 0;

    wr = whites?.rNormalized ?? 0;
    wg = whites?.gNormalized ?? 0;
    wb = whites?.bNormalized ?? 0;

    mr = mids?.rNormalized ?? 0;
    mg = mids?.gNormalized ?? 0;
    mb = mids?.bNormalized ?? 0;

    mr = 1.0 / (1.0 + 2.0 * (mr - 0.5));
    mg = 1.0 / (1.0 + 2.0 * (mg - 0.5));
    mb = 1.0 / (1.0 + 2.0 * (mb - 0.5));
  }

  final num invContrast = contrast != null ? 1.0 - contrast : 0.0;

  if (exposure != null) {
    exposure = pow(2.0, exposure);
  }

  final hsv = <num>[0.0, 0.0, 0.0];

  for (final frame in src.frames) {
    for (final p in frame) {
      final or = p.rNormalized;
      final og = p.gNormalized;
      final ob = p.bNormalized;

      var r = or;
      var g = og;
      var b = ob;

      if (useBlacksWhitesMids) {
        r = pow((r + br) * wr, mr);
        g = pow((g + bg) * wg, mg);
        b = pow((b + bb) * wb, mb);
      }

      if (brightness != null && brightness != 1.0) {
        final tb = brightness.clamp(0, 1000);
        r *= tb;
        g *= tb;
        b *= tb;
      }

      if (saturation != null || hue != null) {
        rgbToHsv(r, g, b, hsv);
        hsv[0] += hue ?? 0.0;
        hsv[1] *= saturation ?? 1.0;
        hsvToRgb(hsv[0], hsv[1], hsv[2], hsv);
        r = hsv[0];
        g = hsv[1];
        b = hsv[2];
      }

      if (contrast != null) {
        r = avgLumR * invContrast + r * contrast;
        g = avgLumG * invContrast + g * contrast;
        b = avgLumB * invContrast + b * contrast;
      }

      if (gamma != null) {
        r = pow(r, gamma);
        g = pow(g, gamma);
        b = pow(b, gamma);
      }

      if (exposure != null) {
        r = r * exposure;
        g = g * exposure;
        b = b * exposure;
      }

      final msk =
          mask?.getPixel(p.x, p.y).getChannelNormalized(maskChannel) ?? 1;
      final blend = msk * amount;

      r = mix(or, r, blend);
      g = mix(og, g, blend);
      b = mix(ob, b, blend);

      p
        ..rNormalized = r.clamp(0.0, 1.0)
        ..gNormalized = g.clamp(0.0, 1.0)
        ..bNormalized = b.clamp(0.0, 1.0);
    }
  }

  return src;
}
