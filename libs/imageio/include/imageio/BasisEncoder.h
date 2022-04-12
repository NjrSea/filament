/*
 * Copyright (C) 2022 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef IMAGE_BASISENCODER_H_
#define IMAGE_BASISENCODER_H_

#include <stddef.h>
#include <stdint.h>
#include <utils/compiler.h>

#include <image/LinearImage.h>

namespace image {

struct BasisEncoderBuilderImpl;
struct BasisEncoderImpl;

class UTILS_PUBLIC BasisEncoder {
public:
    enum IntermediateFormat {
        UASTC,
        ETC1S,
    };

    class Builder {
    public:
        Builder(size_t mipCount) noexcept;
        ~Builder() noexcept;
        Builder(Builder&& that) noexcept;
        Builder& operator=(Builder&& that) noexcept;

        // Enables the linear flag, which does two things:
        // (1) Specifies that the encoder should encode the image without a transfer function.
        // (2) Adds a tag to the ktx file that tells the loader that no transfer function was used.
        // Note that the tag does not actually affect the encoding process. BasisU consumes
        // uint8-based color data, not floats. At the time of this writing, BasisU does not make a
        // distinction between sRGB targets and linear targets.
        Builder& linear(bool enabled) noexcept;

        // Chooses the intermiediate format as described in the BasisU documentation.
        // For highest quality, use UASTC.
        Builder& intermediateFormat(IntermediateFormat format) noexcept;

        // Honors only the first component of the incoming LinearImage.
        Builder& grayscale(bool enabled) noexcept;

        // Transforms the incoming image from [-1, +1] to [0, 1] before passing it to the encoder.
        Builder& normals(bool enabled) noexcept;

        // Submits image data in linear floating-point format.
        Builder& miplevel(size_t mipIndex, const LinearImage& image) noexcept;

        // Initializes the basis encoder with the given number of jobs.
        Builder& jobs(size_t count) noexcept;

        // Supresses status messages.
        Builder& quiet(bool enabled) noexcept;

        // Creates a BasisU encoder and returns null if an error occurred.
        BasisEncoder* build();

    private:
        BasisEncoderBuilderImpl* mImpl;
        Builder(const Builder&) = delete;
        Builder& operator=(const Builder&) = delete;
    };

    ~BasisEncoder() noexcept;
    BasisEncoder(BasisEncoder&& that) noexcept;
    BasisEncoder& operator=(BasisEncoder&& that) noexcept;

    bool encode();

    size_t getKtx2ByteCount() const noexcept;
    uint8_t const* getKtx2Data() const noexcept;

private:
    BasisEncoder(BasisEncoderImpl*) noexcept;
    BasisEncoder(const BasisEncoder&) = delete;
    BasisEncoder& operator=(const BasisEncoder&) = delete;
    BasisEncoderImpl* mImpl;
    friend struct BasisEncoderBuilderImpl;
};

} // namespace image

#endif // IMAGE_BASISENCODER_H_
