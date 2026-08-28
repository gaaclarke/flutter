// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <memory>

#include "flutter/testing/testing.h"
#include "impeller/base/validation.h"
#include "impeller/core/allocator.h"
#include "impeller/core/formats.h"
#include "impeller/core/texture_descriptor.h"
#include "impeller/entity/entity_playground.h"
#include "impeller/entity/render_target_cache.h"
#include "impeller/playground/playground_test.h"
#include "impeller/renderer/testing/mocks.h"

namespace impeller {
namespace testing {

class TestAllocator : public Allocator {
 public:
  TestAllocator() = default;

  ~TestAllocator() = default;

  ISize GetMaxTextureSizeSupported() const override {
    return ISize(1024, 1024);
  };

  std::shared_ptr<DeviceBuffer> OnCreateBuffer(
      const DeviceBufferDescriptor& desc) override {
    if (should_fail) {
      return nullptr;
    }
    return std::make_shared<MockDeviceBuffer>(desc);
  };

  virtual std::shared_ptr<Texture> OnCreateTexture(
      const TextureDescriptor& desc,
      bool threadsafe) override {
    if (should_fail) {
      return nullptr;
    }
    auto tex = std::make_shared<MockTexture>(desc);
    ON_CALL(*tex, IsValid()).WillByDefault(::testing::Return(true));
    ON_CALL(*tex, GetSize()).WillByDefault(::testing::Return(desc.size));
    return tex;
  };

  bool should_fail = false;
};

class RenderTargetCacheTest : public ::testing::Test {
 public:
  void SetUp() override {
    allocator_ = std::make_shared<TestAllocator>();
    context_ = std::make_shared<MockImpellerContext>();
    auto capabilities = std::make_shared<MockCapabilities>();
    EXPECT_CALL(*capabilities, GetDefaultColorFormat())
        .WillRepeatedly(::testing::Return(PixelFormat::kR8G8B8A8UNormInt));
    EXPECT_CALL(*capabilities, SupportsImplicitResolvingMSAA())
        .WillRepeatedly(::testing::Return(false));
    EXPECT_CALL(*capabilities, GetDefaultDepthStencilFormat())
        .WillRepeatedly(::testing::Return(PixelFormat::kS8UInt));
    capabilities_ = capabilities;

    EXPECT_CALL(*context_, GetResourceAllocator())
        .WillRepeatedly(::testing::Return(allocator_));
    EXPECT_CALL(*context_, GetCapabilities())
        .WillRepeatedly(::testing::ReturnRef(capabilities_));
  }

  const std::shared_ptr<MockImpellerContext>& GetContext() const {
    return context_;
  }

  const std::shared_ptr<TestAllocator>& GetAllocator() const {
    return allocator_;
  }

 private:
  std::shared_ptr<TestAllocator> allocator_;
  std::shared_ptr<MockImpellerContext> context_;
  std::shared_ptr<const Capabilities> capabilities_;
};

TEST_F(RenderTargetCacheTest, CachesUsedTexturesAcrossFrames) {
  auto render_target_cache = RenderTargetCache(
      GetContext()->GetResourceAllocator(), /*keep_alive_frame_count=*/0);

  render_target_cache.Start();
  // Create two render targets of the same exact size/shape. Both should be
  // marked as used this frame, so the cached data set will contain two.
  render_target_cache.CreateOffscreen(*GetContext(), {100, 100}, 1);
  render_target_cache.CreateOffscreen(*GetContext(), {100, 100}, 1);

  EXPECT_EQ(render_target_cache.CachedTextureCount(), 2u);

  render_target_cache.End();
  render_target_cache.Start();

  // Next frame, only create one texture. The set will still contain two,
  // but one will be removed at the end of the frame.
  render_target_cache.CreateOffscreen(*GetContext(), {100, 100}, 1);
  EXPECT_EQ(render_target_cache.CachedTextureCount(), 2u);

  render_target_cache.End();
  EXPECT_EQ(render_target_cache.CachedTextureCount(), 1u);
}

TEST_F(RenderTargetCacheTest, CachesUsedTexturesAcrossFramesWithKeepAlive) {
  auto render_target_cache = RenderTargetCache(
      GetContext()->GetResourceAllocator(), /*keep_alive_frame_count=*/3);

  render_target_cache.Start();
  // Create two render targets of the same exact size/shape. Both should be
  // marked as used this frame, so the cached data set will contain two.
  render_target_cache.CreateOffscreen(*GetContext(), {100, 100}, 1);
  render_target_cache.CreateOffscreen(*GetContext(), {100, 100}, 1);

  EXPECT_EQ(render_target_cache.CachedTextureCount(), 2u);

  render_target_cache.End();
  render_target_cache.Start();

  // The unused texture is kept alive until the keep alive countdown
  // reaches 0.
  EXPECT_EQ(render_target_cache.CachedTextureCount(), 2u);

  for (auto i = 0; i < 3; i++) {
    render_target_cache.Start();
    render_target_cache.End();
    EXPECT_EQ(render_target_cache.CachedTextureCount(), 2u);
  }
  // After the countdown has elapsed the texture is removed.
  render_target_cache.Start();
  render_target_cache.End();
  EXPECT_EQ(render_target_cache.CachedTextureCount(), 0u);
}

TEST_F(RenderTargetCacheTest, ReusesTexturesIntraFrame) {
  auto render_target_cache = RenderTargetCache(
      GetContext()->GetResourceAllocator(), /*keep_alive_frame_count=*/0);

  render_target_cache.Start();
  // Pass 1: Allocate target 1.
  std::shared_ptr<Texture> t1_tex;
  {
    RenderTarget target1 =
        render_target_cache.CreateOffscreen(*GetContext(), {100, 100}, 1);
    t1_tex = target1.GetColorAttachment(0).texture;
    EXPECT_EQ(render_target_cache.CachedTextureCount(), 1u);
  }

  // Pass 2: Allocate target 2 (ping-pong consecutive pass).
  // Target 1 was used in pass 1 so cannot be reused immediately in pass 2.
  std::shared_ptr<Texture> t2_tex;
  {
    RenderTarget target2 =
        render_target_cache.CreateOffscreen(*GetContext(), {100, 100}, 1);
    t2_tex = target2.GetColorAttachment(0).texture;
    EXPECT_NE(t1_tex, t2_tex);
    EXPECT_EQ(render_target_cache.CachedTextureCount(), 2u);
  }

  // Pass 3: Request target 3. Since target 1 was used in pass 1 and target 1's
  // reference was dropped, target 1 is safe to reuse in pass 3!
  Texture* raw_t1_tex = t1_tex.get();
  t1_tex.reset();
  {
    RenderTarget target3 =
        render_target_cache.CreateOffscreen(*GetContext(), {100, 100}, 1);
    EXPECT_EQ(render_target_cache.CachedTextureCount(), 2u);
    EXPECT_EQ(target3.GetColorAttachment(0).texture.get(), raw_t1_tex);
  }

  // Pass 4: Request target 4. Reuses target 2!
  Texture* raw_t2_tex = t2_tex.get();
  t2_tex.reset();
  {
    RenderTarget target4 =
        render_target_cache.CreateOffscreen(*GetContext(), {100, 100}, 1);
    EXPECT_EQ(render_target_cache.CachedTextureCount(), 2u);
    EXPECT_EQ(target4.GetColorAttachment(0).texture.get(), raw_t2_tex);
  }

  render_target_cache.End();
}

TEST_F(RenderTargetCacheTest, DoesNotPersistFailedAllocations) {
  ScopedValidationDisable disable;
  auto allocator = std::make_shared<TestAllocator>();
  auto render_target_cache =
      RenderTargetCache(allocator, /*keep_alive_frame_count=*/0);

  render_target_cache.Start();
  allocator->should_fail = true;

  auto render_target =
      render_target_cache.CreateOffscreen(*GetContext(), {100, 100}, 1);

  EXPECT_FALSE(render_target.IsValid());
  EXPECT_EQ(render_target_cache.CachedTextureCount(), 0u);
}

TEST_F(RenderTargetCacheTest, CachedTextureGetsNewAttachmentConfig) {
  auto render_target_cache = RenderTargetCache(
      GetContext()->GetResourceAllocator(), /*keep_alive_frame_count=*/0);

  render_target_cache.Start();
  RenderTarget::AttachmentConfig color_attachment_config =
      RenderTarget::kDefaultColorAttachmentConfig;
  RenderTarget target1 = render_target_cache.CreateOffscreen(
      *GetContext(), {100, 100}, 1, "Offscreen1", color_attachment_config);
  render_target_cache.End();

  render_target_cache.Start();
  color_attachment_config.clear_color = Color::Red();
  RenderTarget target2 = render_target_cache.CreateOffscreen(
      *GetContext(), {100, 100}, 1, "Offscreen2", color_attachment_config);
  render_target_cache.End();

  ColorAttachment color1 = target1.GetColorAttachment(0);
  ColorAttachment color2 = target2.GetColorAttachment(0);
  // The second color attachment should reuse the first attachment's texture
  // but with attributes from the second AttachmentConfig.
  EXPECT_EQ(color2.texture, color1.texture);
  EXPECT_EQ(color2.clear_color, Color::Red());
}

TEST_F(RenderTargetCacheTest, CreateWithEmptySize) {
  auto render_target_cache = RenderTargetCache(
      GetContext()->GetResourceAllocator(), /*keep_alive_frame_count=*/0);

  render_target_cache.Start();
  RenderTarget empty_target =
      render_target_cache.CreateOffscreen(*GetContext(), {100, 0}, 1);
  RenderTarget empty_target_msaa =
      render_target_cache.CreateOffscreenMSAA(*GetContext(), {0, 0}, 1);
  render_target_cache.End();

  {
    ScopedValidationDisable disable_validation;
    EXPECT_FALSE(empty_target.IsValid());
    EXPECT_FALSE(empty_target_msaa.IsValid());
  }
}

}  // namespace testing
}  // namespace impeller
