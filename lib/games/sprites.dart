import 'package:flutter/material.dart';

/// 小游戏贴图（不用表情）。
class GameSprites {
  static const apple = 'assets/games/fruit_apple.jpg';
  static const watermelon = 'assets/games/fruit_watermelon.jpg';
  static const orange = 'assets/games/fruit_orange.jpg';
  static const lemon = 'assets/games/fruit_lemon.jpg';
  static const grape = 'assets/games/fruit_grape.jpg';
  static const strawberry = 'assets/games/fruit_strawberry.jpg';
  static const peach = 'assets/games/fruit_peach.jpg';
  static const kiwi = 'assets/games/fruit_kiwi.jpg';
  static const cherry = 'assets/games/fruit_cherry.jpg';
  static const bomb = 'assets/games/item_bomb.jpg';
  static const basket = 'assets/games/item_basket.jpg';
  static const star = 'assets/games/item_star.jpg';
  static const flower = 'assets/games/mem_flower.jpg';
  static const crown = 'assets/games/mem_crown.jpg';
  static const sun = 'assets/games/mem_sun.jpg';
  static const balloon = 'assets/games/mem_balloon.jpg';
  static const unicorn = 'assets/games/mem_unicorn.jpg';
  static const bunny = 'assets/games/mem_bunny.jpg';
  static const bow = 'assets/games/mem_bow.jpg';
  static const cupcake = 'assets/games/mem_cupcake.jpg';
  static const rainbow = 'assets/games/mem_rainbow.jpg';
  static const cat = 'assets/games/mem_cat.jpg';
  static const cardBack = 'assets/games/mem_card_back.jpg';
  static const runnerHero = 'assets/games/runner_hero.jpg';
  static const runnerBox = 'assets/games/runner_box.jpg';
  static const runnerHedge = 'assets/games/runner_hedge.jpg';
  static const whackMole = 'assets/games/whack_mole.jpg';
  static const whackHole = 'assets/games/whack_hole.jpg';
  static const whackHammer = 'assets/games/whack_hammer.jpg';

  static const fruits = [
    apple,
    watermelon,
    orange,
    lemon,
    grape,
    strawberry,
    peach,
    kiwi,
    cherry,
  ];

  static const memoryFaces = [
    strawberry,
    flower,
    crown,
    star,
    sun,
    balloon,
    unicorn,
    bunny,
    bow,
    cupcake,
    rainbow,
    cat,
  ];

  static Widget img(
    String asset, {
    double? size,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    return ClipOval(
      child: Image.asset(
        asset,
        width: width ?? size,
        height: height ?? size,
        fit: fit,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => SizedBox(
          width: width ?? size,
          height: height ?? size,
          child: const ColoredBox(color: Color(0xFFFFE4EF)),
        ),
      ),
    );
  }

  /// 方形圆角贴图（翻牌 / 障碍）。
  static Widget tile(
    String asset, {
    double? size,
    double? width,
    double? height,
    double radius = 14,
    BoxFit fit = BoxFit.cover,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        asset,
        width: width ?? size,
        height: height ?? size,
        fit: fit,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => SizedBox(
          width: width ?? size,
          height: height ?? size,
          child: const ColoredBox(color: Color(0xFFFFE4EF)),
        ),
      ),
    );
  }
}
